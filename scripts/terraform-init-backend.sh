#!/usr/bin/env bash
# terraform-init-backend.sh — init Terraform with DO Spaces backend
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TF_DIR="${SCRIPT_DIR}/../infra/terraform"

: "${TF_BACKEND_BUCKET:?TF_BACKEND_BUCKET required}"
: "${TF_BACKEND_REGION:?TF_BACKEND_REGION required}"
: "${TF_BACKEND_ACCESS_KEY:?TF_BACKEND_ACCESS_KEY required}"
: "${TF_BACKEND_SECRET_KEY:?TF_BACKEND_SECRET_KEY required}"

TF_STATE_KEY="${TF_STATE_KEY:-k8s-kubeadm-lab/terraform.tfstate}"

cd "$TF_DIR"

terraform init -input=false -reconfigure \
  -backend-config="endpoint=https://${TF_BACKEND_REGION}.digitaloceanspaces.com" \
  -backend-config="region=us-east-1" \
  -backend-config="bucket=${TF_BACKEND_BUCKET}" \
  -backend-config="key=${TF_STATE_KEY}" \
  -backend-config="access_key=${TF_BACKEND_ACCESS_KEY}" \
  -backend-config="secret_key=${TF_BACKEND_SECRET_KEY}" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_metadata_api_check=true" \
  -backend-config="skip_region_validation=true" \
  -backend-config="skip_requesting_account_id=true" \
  -backend-config="skip_s3_checksum=true"
