#!/usr/bin/env bash
# e2e-test.sh — end-to-end checks against live cluster (HTTP + kubectl)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
KUBECONFIG="${KUBECONFIG:-${REPO_ROOT}/kubeconfig}"
export KUBECONFIG

echo "=== E2E: HTTP smoke tests ==="
bash "${SCRIPT_DIR}/smoke-test.sh"

echo "=== E2E: Kubernetes cluster health ==="
kubectl get nodes -o wide
kubectl get pods -n platform
kubectl get pods -n ingress
kubectl get applications -n argocd -o custom-columns=NAME:.metadata.name,SYNC:.status.sync.status,HEALTH:.status.health.status

for app in traefik demo-api demo-frontend postgres; do
  sync="$(kubectl get application "$app" -n argocd -o jsonpath='{.status.sync.status}' 2>/dev/null || echo Missing)"
  health="$(kubectl get application "$app" -n argocd -o jsonpath='{.status.health.status}' 2>/dev/null || echo Missing)"
  if [[ "$sync" != "Synced" || "$health" != "Healthy" ]]; then
    echo "FAIL argocd/$app: sync=$sync health=$health" >&2
    exit 1
  fi
  echo "OK   argocd/$app: Synced/Healthy"
done

echo "=== E2E: demo-api pod ready ==="
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=demo-api -n platform --timeout=120s
kubectl wait --for=condition=Ready pod -l app.kubernetes.io/name=demo-frontend -n platform --timeout=120s

echo "All E2E tests passed."
