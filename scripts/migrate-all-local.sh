#!/usr/bin/env bash
# Runs `prisma migrate deploy` three times in order: root → child 1 → child 2.
#
# Put connection strings in .env (same repo root as this script):
#   DATABASE_URL_ROOT, DATABASE_URL_CHILD_1, DATABASE_URL_CHILD_2
# Then:
#   chmod +x scripts/migrate-all-local.sh && ./scripts/migrate-all-local.sh

set -euo pipefail
cd "$(dirname "$0")/.."

if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

ROOT="${DATABASE_URL_ROOT:?Add DATABASE_URL_ROOT to .env (primary branch)}"
C1="${DATABASE_URL_CHILD_1:?Add DATABASE_URL_CHILD_1 to .env}"
C2="${DATABASE_URL_CHILD_2:?Add DATABASE_URL_CHILD_2 to .env}"

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
