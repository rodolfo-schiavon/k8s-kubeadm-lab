#!/usr/bin/env bash
# run-unit-tests.sh — API unit tests (no cluster required)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
API_DIR="${SCRIPT_DIR}/../apps/api"
VENV="${API_DIR}/.venv-test"

cd "$API_DIR"
python3 -m venv "$VENV"
"${VENV}/bin/pip" install -q -r requirements.txt
PYTHONPATH="${API_DIR}" "${VENV}/bin/pytest" tests/ -v --tb=short
echo "Unit tests passed."
