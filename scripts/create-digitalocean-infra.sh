#!/usr/bin/env bash
# create-digitalocean-infra.sh — Terraform init/plan/apply
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra/terraform"
AUTO_YES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes|-y) AUTO_YES=true; shift ;;
    *) echo "Opção desconhecida: $1" >&2; exit 1 ;;
  esac
done

cd "$TF_DIR"

if [[ ! -f terraform.tfvars ]]; then
  echo "ERROR: terraform.tfvars not found."
  echo "Copy: cp terraform.tfvars.example terraform.tfvars"
  exit 1
fi

if [[ -z "${TF_VAR_do_token:-}" ]]; then
  if command -v doctl &>/dev/null; then
    export TF_VAR_do_token="$(doctl auth list -o json 2>/dev/null | jq -r '.[0].Contexts[0].AccessToken // empty')"
  fi
fi

if [[ -z "${TF_VAR_do_token:-}" ]]; then
  echo "WARNING: TF_VAR_do_token not set."
fi

terraform init
terraform fmt -recursive
terraform validate
terraform plan -out=tfplan

echo
echo "=========================================="
echo "  COST: 3 VPS (~\$72/mo) + Reserved IP"
echo "=========================================="
echo

if [[ "$AUTO_YES" != true ]]; then
  read -r -p "Apply terraform plan? [y/N] " ans
  if [[ "${ans,,}" != "y" ]]; then
    echo "Aborted. Run: terraform apply tfplan"
    exit 0
  fi
fi

terraform apply tfplan
terraform output
