#!/usr/bin/env bash
# lab-lifecycle.sh — destroy, provision, or recreate the k8s lab
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
TF_DIR="${REPO_ROOT}/infra/terraform"

usage() {
  cat <<EOF
Usage: lab-lifecycle.sh <destroy|provision|recreate|validate>

Environment:
  TF_VAR_do_token, TF_VAR_ssh_key_name, TF_VAR_allowed_ssh_cidr
  TF_VAR_assign_ingress_reserved_ip (default: false)
  TF_BACKEND_* (for remote state — see scripts/terraform-init-backend.sh)
  GITHUB_TOKEN (optional — pull private GHCR images on worker-app)
  GHCR_OWNER (default: rodolfo-schiavon)
EOF
}

tf_init() {
  if [[ -n "${TF_BACKEND_BUCKET:-}" ]]; then
    bash "${SCRIPT_DIR}/terraform-init-backend.sh"
  else
    echo "WARNING: TF_BACKEND_BUCKET not set — using local state" >&2
    cd "$TF_DIR" && terraform init -input=false
  fi
}

tf_destroy() {
  tf_init
  cd "$TF_DIR"
  if ! terraform state list &>/dev/null || [[ -z "$(terraform state list 2>/dev/null || true)" ]]; then
    echo "Nothing to destroy (empty or missing state)."
    return 0
  fi
  terraform destroy -auto-approve -input=false
  echo "Destroy complete — no droplets billing."
}

tf_apply() {
  export TF_VAR_assign_ingress_reserved_ip="${TF_VAR_assign_ingress_reserved_ip:-false}"
  tf_init
  cd "$TF_DIR"
  terraform apply -auto-approve -input=false
  terraform output -json > "${REPO_ROOT}/.lab-outputs.json"
  terraform output
}

provision() {
  echo "=== Phase 0: Unit tests ==="
  bash "${SCRIPT_DIR}/run-unit-tests.sh"

  echo "=== Phase 1: Terraform apply ==="
  tf_apply

  echo "=== Phase 2: kubeadm bootstrap ==="
  bash "${SCRIPT_DIR}/bootstrap-cluster.sh" --yes

  echo "=== Phase 3: Argo CD + GitOps ==="
  export KUBECONFIG="${KUBECONFIG:-${REPO_ROOT}/kubeconfig}"
  bash "${SCRIPT_DIR}/install-argocd.sh"

  echo "=== Phase 4: Post-bootstrap ==="
  bash "${SCRIPT_DIR}/post-bootstrap.sh"

  echo "=== Phase 5: E2E tests ==="
  bash "${SCRIPT_DIR}/e2e-test.sh"

  W_APP_IP="$(cd "$TF_DIR" && terraform output -raw worker_app_public_ip)"
  DOMAIN="${TF_VAR_domain_name:-k8s-lab.zerotouch.tec.br}"
  echo
  echo "=========================================="
  echo "  PROVISION COMPLETE"
  echo "=========================================="
  echo "worker_app_public_ip: ${W_APP_IP}"
  echo
  echo "Update DNS A records manually → ${W_APP_IP}:"
  echo "  app.${DOMAIN}"
  echo "  api.${DOMAIN}"
  echo "  argocd.${DOMAIN}"
  echo "  dashboard.${DOMAIN}"
  echo
}

recreate() {
  tf_destroy
  echo "Waiting 30s before reprovision..."
  sleep 30
  provision
}

validate() {
  export KUBECONFIG="${KUBECONFIG:-${REPO_ROOT}/kubeconfig}"
  tf_init
  cd "$TF_DIR"
  CP_IP="$(terraform output -raw control_plane_public_ip)"
  INGRESS_IP="$(terraform output -raw ingress_public_ip)"
  if [[ ! -f "$KUBECONFIG" ]] || ! kubectl cluster-info &>/dev/null; then
    echo "==> Fetching kubeconfig from control plane..."
    scp ${SSH_OPTS:--o StrictHostKeyChecking=no} -q "root@${CP_IP}:/etc/kubernetes/admin.conf" "$KUBECONFIG"
    sed -i "s|server: https://.*:6443|server: https://${INGRESS_IP}:6443|" "$KUBECONFIG"
  fi
  export KUBECONFIG

  bash "${SCRIPT_DIR}/run-unit-tests.sh"
  bash "${SCRIPT_DIR}/post-bootstrap.sh"
  bash "${SCRIPT_DIR}/e2e-test.sh"

  W_APP_IP="$(terraform output -raw worker_app_public_ip)"
  DOMAIN="${TF_VAR_domain_name:-k8s-lab.zerotouch.tec.br}"
  echo "validate complete. DNS → ${W_APP_IP} (app/api/argocd/dashboard.${DOMAIN})"
}

main() {
  local cmd="${1:-}"
  case "$cmd" in
    destroy) tf_destroy ;;
    provision) provision ;;
    recreate) recreate ;;
    validate) validate ;;
    -h|--help|help) usage ;;
    *)
      echo "Unknown command: $cmd" >&2
      usage >&2
      exit 1
      ;;
  esac
}

main "$@"
