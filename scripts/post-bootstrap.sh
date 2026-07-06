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
ARGOCD_WAIT_TIMEOUT="${ARGOCD_WAIT_TIMEOUT:-900}"

if ! kubectl cluster-info &>/dev/null; then
  echo "kubectl cannot reach cluster (KUBECONFIG=${KUBECONFIG})" >&2
  exit 1
fi

cd "$TF_DIR"
W_APP_IP="$(terraform output -raw worker_app_public_ip)"

echo "==> Traefik namespace: privileged PSS for hostNetwork :80"
kubectl create namespace ingress --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace ingress pod-security.kubernetes.io/enforce=privileged --overwrite 2>/dev/null || true

echo "==> Waiting for core platform pods..."
for ns in argocd cert-manager ingress; do
  kubectl wait --for=condition=Ready pods --all -n "$ns" --timeout=300s 2>/dev/null || true
done

echo "==> Waiting for Argo CD applications (timeout ${ARGOCD_WAIT_TIMEOUT}s)..."
KEY_APPS=(traefik cert-manager metrics-server postgres demo-api demo-frontend kubernetes-dashboard)
deadline=$((SECONDS + ARGOCD_WAIT_TIMEOUT))
while (( SECONDS < deadline )); do
  all_ok=true
  for app in "${KEY_APPS[@]}"; do
  sync="$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo "Missing")"
  health="$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo "Missing")"
  echo "  $app: sync=$sync health=$health"
  if [[ "$sync" != "Synced" ]] || [[ "$health" != "Healthy" ]]; then
    all_ok=false
  fi
  done
  if [[ "$all_ok" == true ]]; then
    echo "Key Argo CD applications healthy."
    break
  fi
  sleep 20
done

echo "==> Waiting for demo workloads..."
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=demo-api -n platform --timeout=300s 2>/dev/null || true
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=demo-frontend -n platform --timeout=300s 2>/dev/null || true

echo "==> Pull demo images on worker-app (GHCR)..."
if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  ssh $SSH_OPTS "root@${W_APP_IP}" bash -s <<REMOTE
set -euo pipefail
echo "${GITHUB_TOKEN}" | crictl pull --creds "${GHCR_OWNER}:${GITHUB_TOKEN}" "${API_IMAGE}" || true
echo "${GITHUB_TOKEN}" | crictl pull --creds "${GHCR_OWNER}:${GITHUB_TOKEN}" "${FRONT_IMAGE}" || true
crictl images | grep k8s-lab-demo || true
REMOTE
  kubectl rollout restart deployment/demo-api deployment/demo-frontend -n platform
  kubectl rollout status deployment/demo-api -n platform --timeout=180s || true
  kubectl rollout status deployment/demo-frontend -n platform --timeout=180s || true
else
  echo "GITHUB_TOKEN not set — assuming public GHCR packages or images already present."
fi

echo "==> Platform status"
kubectl get pods -n platform
kubectl get pods -n ingress
kubectl get applications -n argocd

echo "post-bootstrap complete."
