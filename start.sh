#!/bin/sh
# Start mcpo on Railway. Exits non-zero on any setup error so Railway's
# ON_FAILURE restart policy and the deploy health check see the failure.
set -eu

DATA="${MCPO_DATA_DIR:-/data}"
CONFIG="$DATA/config.json"
mkdir -p "$DATA" "$DATA/.cache"

if [ -z "${MCPO_API_KEY:-}" ]; then
  echo "start.sh: MCPO_API_KEY is empty. Set it (the template generates one) so the API is not open to everyone." >&2
  exit 1
fi

if [ -n "${MCPO_CONFIG:-}" ]; then
  # MCPO_CONFIG holds the whole config, as JSON or base64-encoded JSON. It wins over the file.
  case "$MCPO_CONFIG" in
    \{*) printf '%s' "$MCPO_CONFIG" > "$CONFIG.new" ;;
    *)   printf '%s' "$MCPO_CONFIG" | base64 -d > "$CONFIG.new" || { echo "start.sh: MCPO_CONFIG is neither JSON nor base64" >&2; exit 1; } ;;
  esac
  mv "$CONFIG.new" "$CONFIG"
  echo "start.sh: wrote $CONFIG from MCPO_CONFIG"
elif [ ! -s "$CONFIG" ]; then
  cp /app/config.default.json "$CONFIG"
  echo "start.sh: first boot, wrote the example config to $CONFIG (time, memory, fetch)"
fi

python -c 'import json,sys; c=json.load(open(sys.argv[1])); assert c.get("mcpServers"), "no mcpServers"' "$CONFIG" \
  || { echo "start.sh: $CONFIG is not a valid mcpo config (needs a JSON object with mcpServers)" >&2; exit 1; }

exec python /app/launcher.py
