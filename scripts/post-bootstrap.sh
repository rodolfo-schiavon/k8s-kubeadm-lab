#!/usr/bin/env bash
# post-bootstrap.sh — wait for GitOps, Traefik PSS, GHCR images on worker-app
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
TF_DIR="${REPO_ROOT}/infra/terraform"
KUBECONFIG="${KUBECONFIG:-${REPO_ROOT}/kubeconfig}"
export KUBECONFIG

SSH_OPTS="${SSH_OPTS:--o StrictHostKeyChecking=no -o ConnectTimeout=30}"
GHCR_OWNER="${GHCR_OWNER:-rodolfo-schiavon}"
API_IMAGE="ghcr.io/${GHCR_OWNER}/k8s-lab-demo-api:latest"
FRONT_IMAGE="ghcr.io/${GHCR_OWNER}/k8s-lab-demo-frontend:latest"
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-600}"

if ! kubectl cluster-info &>/dev/null; then
  echo "kubectl cannot reach cluster (KUBECONFIG=${KUBECONFIG})" >&2
  exit 1
fi

cd "$TF_DIR"
W_APP_IP="$(terraform output -raw worker_app_public_ip)"

bash "${SCRIPT_DIR}/ensure-calico-vxlan.sh"

echo "==> Traefik namespace: privileged PSS for hostNetwork :80"
kubectl create namespace ingress --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace ingress pod-security.kubernetes.io/enforce=privileged --overwrite 2>/dev/null || true

echo "==> Restart CoreDNS..."
kubectl rollout restart deployment/coredns -n kube-system
kubectl rollout status deployment/coredns -n kube-system --timeout=120s

echo "==> Wait for postgres pod..."
kubectl wait --for=condition=Ready pod/postgres-0 -n data-services --timeout=300s

echo "==> Wait for platform foundation (timeout ${ARGOCD_WAIT_TIMEOUT}s)..."
FOUNDATION_APPS=(traefik cert-manager metrics-server)
deadline=$((SECONDS + ARGOCD_WAIT_TIMEOUT))
while (( SECONDS < deadline )); do
  all_ok=true
  for app in "${FOUNDATION_APPS[@]}"; do
    sync="$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo Missing)"
    health="$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo Missing)"
    echo "  $app: sync=$sync health=$health"
    if [[ "$sync" != "Synced" ]] || [[ "$health" != "Healthy" ]]; then
      all_ok=false
    fi
  done
  if [[ "$all_ok" == true ]]; then
    break
  fi
  sleep 15
done

echo "==> Pull demo images on worker-app (GHCR)..."
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  ssh $SSH_OPTS "root@${W_APP_IP}" bash -s <<REMOTE
set -euo pipefail
echo "${GITHUB_TOKEN}" | crictl pull --creds "${GHCR_OWNER}:${GITHUB_TOKEN}" "${API_IMAGE}" || true
echo "${GITHUB_TOKEN}" | crictl pull --creds "${GHCR_OWNER}:${GITHUB_TOKEN}" "${FRONT_IMAGE}" || true
REMOTE
fi

kubectl scale deployment demo-api -n platform --replicas=1
kubectl delete hpa demo-api -n platform --ignore-not-found
kubectl delete application postgres-networkpolicy -n argocd --ignore-not-found
kubectl rollout restart deployment/demo-api deployment/demo-frontend -n platform
kubectl rollout status deployment/demo-api -n platform --timeout=300s
kubectl rollout status deployment/demo-frontend -n platform --timeout=300s

wait_ready_pods() {
  local label="$1" ns="$2" timeout="${3:-300}"
  local end=$((SECONDS + timeout))
  while (( SECONDS < end )); do
    local not_ready
    not_ready="$(kubectl get pods -n "$ns" -l "$label" --field-selector=status.phase=Running \
      -o jsonpath='{range .items[*]}{.status.conditions[?(@.type=="Ready")].status}{" "}{end}' | grep -c False || true)"
    if [[ "$not_ready" == "0" ]] && [[ -n "$(kubectl get pods -n "$ns" -l "$label" --field-selector=status.phase=Running -o name 2>/dev/null)" ]]; then
      echo "Pods ready: $label"
      return 0
    fi
    sleep 5
  done
  kubectl get pods -n "$ns" -l "$label" -o wide
  return 1
}

wait_ready_pods "app.kubernetes.io/name=demo-api" platform 300
wait_ready_pods "app.kubernetes.io/name=demo-frontend" platform 300

kubectl get pods -n platform
kubectl get pods -n ingress
kubectl get applications -n argocd

echo "post-bootstrap complete."
