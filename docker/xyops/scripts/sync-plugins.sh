#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SECRETS="$SCRIPT_DIR/../.secrets"
PLUGINS_DIR="$SCRIPT_DIR/../plugins"

if [[ ! -f "$SECRETS" ]]; then
  echo "ERROR: .secrets not found at $SECRETS" >&2
  exit 1
fi

# shellcheck source=/dev/null
source "$SECRETS"

for dep in curl jq; do
  if ! command -v "$dep" &>/dev/null; then
    echo "ERROR: $dep is required but not installed" >&2
    exit 1
  fi
done

shopt -s nullglob
defs=("$PLUGINS_DIR"/*/plugin-def.json)
if [[ ${#defs[@]} -eq 0 ]]; then
  echo "No plugin-def.json files found under $PLUGINS_DIR"
  exit 0
fi

for def in "${defs[@]}"; do
  plugin_name="$(basename "$(dirname "$def")")"

  plugin_data="$(jq '.items[0].data' "$def")"
  plugin_id="$(echo "$plugin_data" | jq -r '.id')"

  printf "  %-20s (%s): " "$plugin_name" "$plugin_id"

  existing="$(curl -sf \
    -H "X-API-Key: $XYOPS_API_KEY" \
    "$XYOPS_BASE_URL/api/app/get_plugin/v1?id=$plugin_id" 2>/dev/null || echo '{"code":1}')"

  if [[ "$(echo "$existing" | jq -r '.code')" == "0" ]]; then
    result="$(curl -sf -X POST \
      -H "X-API-Key: $XYOPS_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$plugin_data" \
      "$XYOPS_BASE_URL/api/app/update_plugin/v1")"
    if [[ "$(echo "$result" | jq -r '.code')" == "0" ]]; then
      echo "updated"
    else
      echo "FAILED to update: $(echo "$result" | jq -r '.description')"
    fi
  else
    result="$(curl -sf -X POST \
      -H "X-API-Key: $XYOPS_API_KEY" \
      -H "Content-Type: application/json" \
      -d "$plugin_data" \
      "$XYOPS_BASE_URL/api/app/create_plugin/v1")"
    if [[ "$(echo "$result" | jq -r '.code')" == "0" ]]; then
      echo "created"
    else
      echo "FAILED to create: $(echo "$result" | jq -r '.description')"
    fi
  fi
done
