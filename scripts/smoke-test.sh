#!/usr/bin/env bash
# smoke-test.sh — HTTP checks via worker-app IP + Host headers
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="${SCRIPT_DIR}/.."
TF_DIR="${REPO_ROOT}/infra/terraform"
DOMAIN="${TF_VAR_domain_name:-k8s-lab.zerotouch.tec.br}"

cd "$TF_DIR"
if ! terraform output -raw worker_app_public_ip &>/dev/null; then
  echo "ERROR: terraform outputs not available" >&2
  exit 1
fi

W_APP_IP="$(terraform output -raw worker_app_public_ip)"
echo "Smoke tests via ${W_APP_IP} (Traefik hostNetwork :80)"

check_http() {
  local name="$1" host="$2" path="$3" expect="$4"
  local code body
  code="$(curl -s -o /tmp/smoke-body.txt -w "%{http_code}" --max-time 20 \
    -H "Host: ${host}" "http://${W_APP_IP}${path}")"
  body="$(head -c 200 /tmp/smoke-body.txt)"
  if [[ "$code" != "$expect" ]]; then
    echo "FAIL ${name}: HTTP ${code} (expected ${expect}) body=${body}" >&2
    return 1
  fi
  echo "OK   ${name}: HTTP ${code}"
}

fail=0
check_http "frontend" "app.${DOMAIN}" "/" "200" || fail=1
check_http "api-healthz" "api.${DOMAIN}" "/healthz" "200" || fail=1
check_http "api-readyz" "api.${DOMAIN}" "/readyz" "200" || fail=1

echo "==> POST /api/items"
post_code="$(curl -s -o /tmp/smoke-post.txt -w "%{http_code}" --max-time 20 \
  -H "Host: api.${DOMAIN}" -H "Content-Type: application/json" \
  -X POST -d '{"title":"smoke-test"}' "http://${W_APP_IP}/api/items")"
if [[ "$post_code" != "200" ]]; then
  echo "FAIL api-post: HTTP ${post_code} body=$(cat /tmp/smoke-post.txt)" >&2
  fail=1
else
  echo "OK   api-post: HTTP ${post_code}"
fi

echo "==> GET /api/items via frontend proxy"
proxy_code="$(curl -s -o /tmp/smoke-proxy.txt -w "%{http_code}" --max-time 20 \
  -H "Host: app.${DOMAIN}" "http://${W_APP_IP}/api/items")"
if [[ "$proxy_code" != "200" ]]; then
  echo "FAIL frontend-proxy: HTTP ${proxy_code} body=$(head -c 200 /tmp/smoke-proxy.txt)" >&2
  fail=1
else
  echo "OK   frontend-proxy: HTTP ${proxy_code}"
fi

if [[ "$fail" -ne 0 ]]; then
  echo "Smoke tests FAILED" >&2
  exit 1
fi

echo "All smoke tests passed."
