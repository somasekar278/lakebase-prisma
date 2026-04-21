#!/usr/bin/env bash
# Runs `prisma migrate deploy` three times in order: root → child 1 → child 2.
#
# Put connection strings in .env (same repo root as this script):
#   DATABASE_URL_ROOT, DATABASE_URL_CHILD_1, DATABASE_URL_CHILD_2
# Then:
#   chmod +x scripts/migrate-all-local.sh && ./scripts/migrate-all-local.sh

set -euo pipefail
cd "$(dirname "$0")/.."

# Do not `source .env`: URLs with ?a=1&b=2 break bash (`&` is a control operator).
# Load KEY=value lines and export with proper quoting.
if [[ -f .env ]]; then
  eval "$(python3 <<'PY'
import pathlib, shlex

def load(p: pathlib.Path) -> None:
    for raw in p.read_text().splitlines():
        line = raw.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("export "):
            line = line[7:].strip()
        if "=" not in line:
            continue
        key, _, val = line.partition("=")
        key, val = key.strip(), val.strip()
        if len(val) >= 2 and val[0] == val[-1] and val[0] in "\"'":
            val = val[1:-1]
        print(f"export {key}={shlex.quote(val)}")

load(pathlib.Path(".env"))
PY
)"
fi

# Primary branch: DATABASE_URL_ROOT, or fall back to DATABASE_URL (common for local dev).
ROOT="${DATABASE_URL_ROOT:-${DATABASE_URL:?Set DATABASE_URL_ROOT or DATABASE_URL for primary branch}}"
C1="${DATABASE_URL_CHILD_1:?Add DATABASE_URL_CHILD_1 to .env}"
C2="${DATABASE_URL_CHILD_2:?Add DATABASE_URL_CHILD_2 to .env}"

# Schema requires SHADOW_DATABASE_URL ≠ DATABASE_URL. Do not reuse the migrate target URL as shadow.
# Use the empty shadow DB from .env (same one as `migrate dev`) for every deploy — Prisma does not run shadow steps during `migrate deploy`.
SHADOW="${SHADOW_DATABASE_URL:?Set SHADOW_DATABASE_URL in .env (empty DB, usually on primary branch)}"

run() {
  local label="$1"
  local url="$2"
  echo "=== ${label} ==="
  DATABASE_URL="$url" SHADOW_DATABASE_URL="$SHADOW" npm run db:migrate:deploy
}

run "root" "$ROOT"
run "child 1" "$C1"
run "child 2" "$C2"
echo "Done."
