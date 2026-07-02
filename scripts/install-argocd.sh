#!/usr/bin/env bash
# install-argocd.sh — Helm install Argo CD + app-of-apps
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
ARGOCD_GITOPS="${REPO_ROOT}/gitops/clusters/lab/argocd"
KUBECONFIG="${KUBECONFIG:-${REPO_ROOT}/kubeconfig}"
export KUBECONFIG

if ! kubectl cluster-info &>/dev/null; then
  echo "kubectl não conecta. Verifique KUBECONFIG=${KUBECONFIG}" >&2
  exit 1
fi

if ! command -v helm &>/dev/null; then
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
fi

helm repo add argo https://argoproj.github.io/argo-helm 2>/dev/null || true
helm repo update

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -

helm upgrade --install argocd argo/argo-cd \
  --namespace argocd \
  --set global.nodeSelector."node-role"=control-plane \
  --set controller.nodeSelector."node-role"=control-plane \
  --set server.nodeSelector."node-role"=control-plane \
  --set repoServer.nodeSelector."node-role"=control-plane \
  --set applicationSet.nodeSelector."node-role"=control-plane \
  --set redis.nodeSelector."node-role"=control-plane \
  --set dex.nodeSelector."node-role"=control-plane \
  --set notifications.nodeSelector."node-role"=control-plane \
  --set server.ingress.enabled=false \
  --set configs.params."server\.insecure"=true \
  --wait --timeout 10m

if [[ -f "${ARGOCD_GITOPS}/ingress-values.yaml" ]]; then
  helm upgrade argocd argo/argo-cd -n argocd \
    --reuse-values \
    -f "${ARGOCD_GITOPS}/ingress-values.yaml" \
    --wait --timeout 5m
fi

kubectl apply -f "${ARGOCD_GITOPS}/app-of-apps.yaml"
echo "Argo CD installed. Password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d"
