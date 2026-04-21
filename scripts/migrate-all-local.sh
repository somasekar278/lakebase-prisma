#!/usr/bin/env bash
# Mirrors CI deploy order: root → child 1 → child 2.
# Export these in your shell (e.g. from .env via set -a && source .env), then:
#   chmod +x scripts/migrate-all-local.sh
#   ./scripts/migrate-all-local.sh

set -euo pipefail
ROOT="${DATABASE_URL_ROOT:?Set DATABASE_URL_ROOT}"
C1="${DATABASE_URL_CHILD_1:?Set DATABASE_URL_CHILD_1}"
C2="${DATABASE_URL_CHILD_2:?Set DATABASE_URL_CHILD_2}"

cd "$(dirname "$0")/.."

run() {
  local label="$1"
  local url="$2"
  echo "=== ${label} ==="
  DATABASE_URL="$url" SHADOW_DATABASE_URL="$url" npm run db:migrate:deploy
}

run "root" "$ROOT"
run "child 1" "$C1"
run "child 2" "$C2"
echo "Done."
