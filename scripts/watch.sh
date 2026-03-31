#!/usr/bin/env bash
# Supply Chain Watcher - Monitors lockfile changes and alerts on threats
# https://github.com/oopsalldev/npm-supply-chain-scanner
# License: MIT (c) 2026 oops.zone

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER="$SCRIPT_DIR/scan.sh"
WATCH_PATH="${1:-.}"
INTERVAL="${2:-300}"  # Default: check every 5 minutes
WEBHOOK_URL="${SUPPLY_CHAIN_WEBHOOK:-}"

RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo -e "${BLUE}[$(date -u '+%H:%M:%S')]${NC} $1"; }

send_alert() {
  local message="$1"
  if [ -n "$WEBHOOK_URL" ]; then
    curl -s -X POST "$WEBHOOK_URL" \
      -H "Content-Type: application/json" \
      -d "{\"text\": \"$message\"}" >/dev/null 2>&1 || true
  fi
  echo -e "${RED}[ALERT]${NC} $message"
}

# Track lockfile checksums
declare -A LOCKFILE_HASHES

compute_hashes() {
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    LOCKFILE_HASHES["$f"]=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
  done < <(find "$WATCH_PATH" \( -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" -o -name "requirements.txt" -o -name "Pipfile.lock" -o -name "Gemfile.lock" -o -name "Cargo.lock" -o -name "composer.lock" -o -name "go.sum" \) -not -path "*/node_modules/*" 2>/dev/null)
}

echo ""
echo "Supply Chain Watcher"
echo "Monitoring: $(realpath "$WATCH_PATH")"
echo "Interval: ${INTERVAL}s"
[ -n "$WEBHOOK_URL" ] && echo "Webhook: configured"
echo "---"
echo ""

# Initial scan
log "Running initial scan..."
bash "$SCANNER" --path "$WATCH_PATH" || true
compute_hashes

log "Watching for lockfile changes... (Ctrl+C to stop)"
echo ""

while true; do
  sleep "$INTERVAL"

  changed=false
  while IFS= read -r f; do
    [ -z "$f" ] && continue
    current_hash=$(sha256sum "$f" 2>/dev/null | awk '{print $1}')
    previous_hash="${LOCKFILE_HASHES[$f]:-}"

    if [ "$current_hash" != "$previous_hash" ]; then
      changed=true
      log "Lockfile changed: $f"
      LOCKFILE_HASHES["$f"]="$current_hash"
    fi
  done < <(find "$WATCH_PATH" \( -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" -o -name "requirements.txt" -o -name "Pipfile.lock" -o -name "Gemfile.lock" -o -name "Cargo.lock" -o -name "composer.lock" -o -name "go.sum" \) -not -path "*/node_modules/*" 2>/dev/null)

  if [ "$changed" = true ]; then
    log "Change detected! Running scan..."
    output=$(bash "$SCANNER" --path "$WATCH_PATH" 2>&1) || true

    if echo "$output" | grep -q "COMPROMISED"; then
      send_alert "SUPPLY CHAIN COMPROMISE DETECTED on $(hostname)! Check immediately."
    fi

    echo "$output"
  fi
done
