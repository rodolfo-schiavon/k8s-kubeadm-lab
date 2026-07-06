#!/usr/bin/env bash
# ghcr-make-public.sh — set GHCR package visibility to public (lab images)
set -euo pipefail

OWNER="${GHCR_OWNER:-rodolfo-schiavon}"
PACKAGES=(k8s-lab-demo-api k8s-lab-demo-frontend)

if [[ -z "${GITHUB_TOKEN:-}" ]]; then
  echo "GITHUB_TOKEN required (needs write:packages)" >&2
  exit 1
fi

for pkg in "${PACKAGES[@]}"; do
  echo "Setting ${OWNER}/${pkg} to public..."
  status="$(curl -s -o /tmp/ghcr-pkg.json -w "%{http_code}" -X PATCH \
    -H "Authorization: Bearer ${GITHUB_TOKEN}" \
    -H "Accept: application/vnd.github+json" \
    -H "X-GitHub-Api-Version: 2022-11-28" \
    "https://api.github.com/user/packages/container/${pkg}" \
    -d '{"visibility":"public"}')" || status="000"
  if [[ "$status" == "200" ]]; then
    echo "  OK ${pkg}"
  else
    echo "  WARN ${pkg}: HTTP ${status} — set visibility manually in GitHub Packages"
    cat /tmp/ghcr-pkg.json 2>/dev/null || true
  fi
done

echo "Done. Verify at https://github.com/users/${OWNER}?tab=packages"
