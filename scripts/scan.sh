#!/usr/bin/env bash
# Supply Chain Scanner - Multi-ecosystem dependency scanner
# https://github.com/oopsalldev/npm-supply-chain-scanner
# License: MIT (c) 2026 oops.zone

set -uo pipefail

VERSION="1.0.0"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
THREATS_DIR="$SCRIPT_DIR/threats"
SCAN_PATH="."
SEVERITY_THRESHOLD="low"
ECOSYSTEMS="all"
CI_MODE=false
COMPROMISED_COUNT=0
WARNING_COUNT=0
CLEAN_COUNT=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

usage() {
  echo "Supply Chain Scanner v${VERSION}"
  echo ""
  echo "Usage: scan.sh [OPTIONS]"
  echo ""
  echo "Options:"
  echo "  --path PATH          Directory to scan (default: current directory)"
  echo "  --severity LEVEL     Minimum severity: critical, high, medium, low (default: low)"
  echo "  --ecosystems LIST    Comma-separated: npm,pypi,rubygems,cargo,composer,go,nuget,all (default: all)"
  echo "  --ci-mode            Output in CI-friendly format"
  echo "  --update             Update threat database from GitHub"
  echo "  --version            Show version"
  echo "  --help               Show this help"
}

log_clean() { echo -e "${GREEN}[CLEAN]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARNING]${NC} $1"; ((WARNING_COUNT++)) || true; }
log_compromised() { echo -e "${RED}[COMPROMISED]${NC} $1"; ((COMPROMISED_COUNT++)) || true; }
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }

update_threats() {
  log_info "Updating threat database..."
  if command -v git &>/dev/null; then
    cd "$SCRIPT_DIR" && git pull origin main --quiet
    log_info "Threat database updated."
  else
    log_warn "git not found. Download manually from https://github.com/oopsalldev/npm-supply-chain-scanner"
  fi
}

# Parse JSON without jq (fallback)
json_extract() {
  local file="$1" key="$2"
  if command -v jq &>/dev/null; then
    jq -r "$key" "$file" 2>/dev/null
  else
    python3 -c "import json,sys; data=json.load(open('$file')); print(eval(\"data$key\"))" 2>/dev/null || echo ""
  fi
}

scan_npm() {
  local threat_file="$1"

  if ! command -v jq &>/dev/null; then
    log_warn "jq required for npm scanning. Skipping."
    return
  fi

  # Pre-extract affected package names and their compromised versions
  local num_affected
  num_affected=$(jq '.affected_packages | length' "$threat_file" 2>/dev/null)
  [ "$num_affected" = "0" ] && return

  for ((i=0; i<num_affected; i++)); do
    local pkg_name
    pkg_name=$(jq -r ".affected_packages[$i].name" "$threat_file" 2>/dev/null)
    [ -z "$pkg_name" ] || [ "$pkg_name" = "null" ] && continue

    # Derive the directory name from the package name (handle scoped packages)
    local pkg_dir="$pkg_name"

    # Find only this specific package in node_modules (much faster)
    while IFS= read -r pkg_json; do
      [ -z "$pkg_json" ] && continue
      local installed_version
      installed_version=$(grep -o '"version": "[^"]*"' "$pkg_json" | head -1 | cut -d'"' -f4)
      [ -z "$installed_version" ] && continue

      local is_compromised=false
      local num_versions
      num_versions=$(jq ".affected_packages[$i].compromised_versions | length" "$threat_file" 2>/dev/null)

      for ((j=0; j<num_versions; j++)); do
        local bad_version
        bad_version=$(jq -r ".affected_packages[$i].compromised_versions[$j]" "$threat_file" 2>/dev/null)
        if [ "$installed_version" = "$bad_version" ]; then
          is_compromised=true
          break
        fi
      done

      if [ "$is_compromised" = true ]; then
        log_compromised "$pkg_name@$installed_version | Path: $pkg_json"
      else
        log_clean "$pkg_name@$installed_version (safe)"
      fi
    done < <(find "$SCAN_PATH" -path "*/node_modules/${pkg_dir}/package.json" 2>/dev/null; find "$SCAN_PATH" -path "*/node_modules/.pnpm/${pkg_dir}@*/node_modules/${pkg_dir}/package.json" 2>/dev/null)
  done
}

scan_malicious_dirs() {
  local threat_file="$1"
  local num_dirs
  num_dirs=$(jq '.malicious_indicators.directories | length' "$threat_file" 2>/dev/null)
  [ "$num_dirs" = "0" ] || [ -z "$num_dirs" ] && return

  for ((i=0; i<num_dirs; i++)); do
    local dir_name
    dir_name=$(jq -r ".malicious_indicators.directories[$i]" "$threat_file" 2>/dev/null)
    local found
    found=$(find "$SCAN_PATH" -type d -name "$dir_name" 2>/dev/null | head -5)
    if [ -n "$found" ]; then
      log_compromised "Malicious directory '$dir_name' found: $found"
    fi
  done
}

scan_malicious_files() {
  local threat_file="$1"
  local num_files
  num_files=$(jq '.malicious_indicators.files | length' "$threat_file" 2>/dev/null)
  [ "$num_files" = "0" ] || [ -z "$num_files" ] && return

  for ((i=0; i<num_files; i++)); do
    local file_name
    file_name=$(jq -r ".malicious_indicators.files[$i]" "$threat_file" 2>/dev/null)
    local found
    found=$(find "$SCAN_PATH" -name "$file_name" -not -path "*/node_modules/.cache/*" 2>/dev/null | head -5)
    if [ -n "$found" ]; then
      log_warn "Suspicious file '$file_name' found: $found (verify manually)"
    fi
  done
}

scan_file_artifacts() {
  local threat_file="$1"
  local os_type="linux"
  [[ "$(uname)" == "Darwin" ]] && os_type="macos"
  [[ "$(uname)" == MINGW* ]] || [[ "$(uname)" == CYGWIN* ]] && os_type="windows"

  local num_artifacts
  num_artifacts=$(jq ".file_artifacts.$os_type | length" "$threat_file" 2>/dev/null)
  [ "$num_artifacts" = "0" ] || [ -z "$num_artifacts" ] && return

  for ((i=0; i<num_artifacts; i++)); do
    local artifact_path
    artifact_path=$(jq -r ".file_artifacts.$os_type[$i]" "$threat_file" 2>/dev/null)
    # Expand Windows env vars
    artifact_path="${artifact_path/\%TEMP\%/${TMPDIR:-/tmp}}"
    artifact_path="${artifact_path/\%PROGRAMDATA\%/C:/ProgramData}"

    if [ -f "$artifact_path" ]; then
      log_compromised "Malware artifact found: $artifact_path"
    fi
  done
}

CACHED_CONNECTIONS=""
CONNECTIONS_CACHED=false

scan_network() {
  local threat_file="$1"
  local num_patterns
  num_patterns=$(jq '.malicious_indicators.network_patterns | length' "$threat_file" 2>/dev/null)
  [ "$num_patterns" = "0" ] || [ -z "$num_patterns" ] && return

  # Cache connections once
  if [ "$CONNECTIONS_CACHED" = false ]; then
    if command -v ss &>/dev/null; then
      CACHED_CONNECTIONS=$(ss -tunp 2>/dev/null || true)
    fi
    CONNECTIONS_CACHED=true
  fi
  [ -z "$CACHED_CONNECTIONS" ] && return

  for ((i=0; i<num_patterns; i++)); do
    local pattern
    pattern=$(jq -r ".malicious_indicators.network_patterns[$i]" "$threat_file" 2>/dev/null)
    [ -z "$pattern" ] && continue
    [[ "$pattern" == "github.com" ]] && continue

    if echo "$CACHED_CONNECTIONS" | grep -qi "$pattern" 2>/dev/null; then
      log_compromised "Active C2 connection detected: $pattern"
    fi
  done
}

scan_lockfiles() {
  local threat_file="$1"

  # Check npm lockfiles for compromised shasums
  local num_affected
  num_affected=$(jq '.affected_packages | length' "$threat_file" 2>/dev/null)

  for ((i=0; i<num_affected; i++)); do
    local shasums
    shasums=$(jq -r ".affected_packages[$i].shasum | values[]" "$threat_file" 2>/dev/null)
    [ -z "$shasums" ] && continue

    while IFS= read -r lockfile; do
      [ -z "$lockfile" ] && continue
      for sha in $shasums; do
        [ -z "$sha" ] && continue
        if grep -q "$sha" "$lockfile" 2>/dev/null; then
          log_compromised "Compromised shasum ($sha) found in: $lockfile"
        fi
      done
    done < <(find "$SCAN_PATH" \( -name "package-lock.json" -o -name "yarn.lock" -o -name "pnpm-lock.yaml" \) -not -path "*/node_modules/*" 2>/dev/null | head -50)
  done
}

scan_html_patterns() {
  local threat_file="$1"
  local patterns
  patterns=$(jq -r '.malicious_indicators.html_patterns // [] | .[]' "$threat_file" 2>/dev/null)
  [ -z "$patterns" ] && return

  for pattern in $patterns; do
    local found
    found=$(grep -rl "$pattern" "$SCAN_PATH" --include="*.html" --include="*.htm" --include="*.ejs" --include="*.hbs" --include="*.blade.php" --include="*.twig" --include="*.jsx" --include="*.tsx" --include="*.vue" --exclude-dir="node_modules" --exclude-dir=".git" --exclude-dir="vendor" --exclude-dir="dist" 2>/dev/null | head -10)
    if [ -n "$found" ]; then
      log_compromised "Malicious CDN reference '$pattern' found in: $(echo "$found" | tr '\n' ', ')"
    fi
  done
}

CACHED_PIP_LIST=""
PIP_CACHED=false

scan_pypi() {
  local threat_file="$1"

  # Check pip packages - cache pip list once
  if [ "$PIP_CACHED" = false ]; then
    if command -v pip3 &>/dev/null; then
      CACHED_PIP_LIST=$(pip3 freeze 2>/dev/null || true)
    elif command -v pip &>/dev/null; then
      CACHED_PIP_LIST=$(pip freeze 2>/dev/null || true)
    fi
    PIP_CACHED=true
  fi

  local num_affected
  num_affected=$(jq '.affected_packages | length' "$threat_file" 2>/dev/null)

  for ((i=0; i<num_affected; i++)); do
    local pkg_name
    pkg_name=$(jq -r ".affected_packages[$i].name" "$threat_file" 2>/dev/null)
    [ -z "$pkg_name" ] || [ "$pkg_name" = "null" ] && continue

    # Check against cached pip list (fast)
    local installed_version
    installed_version=$(echo "$CACHED_PIP_LIST" | grep -i "^${pkg_name}==" | head -1 | cut -d'=' -f3)
    [ -z "$installed_version" ] && continue

    local num_versions
    num_versions=$(jq ".affected_packages[$i].compromised_versions | length" "$threat_file" 2>/dev/null)

    for ((j=0; j<num_versions; j++)); do
      local bad_version
      bad_version=$(jq -r ".affected_packages[$i].compromised_versions[$j]" "$threat_file" 2>/dev/null)
      if [ "$installed_version" = "$bad_version" ]; then
        log_compromised "PyPI: $pkg_name@$installed_version is compromised!"
      fi
    done
  done

  # Also check requirements.txt and pyproject.toml
  while IFS= read -r reqfile; do
    [ -z "$reqfile" ] && continue
    for ((i=0; i<num_affected; i++)); do
      local pkg_name
      pkg_name=$(jq -r ".affected_packages[$i].name" "$threat_file" 2>/dev/null)
      if grep -qi "$pkg_name" "$reqfile" 2>/dev/null; then
        log_warn "PyPI package '$pkg_name' referenced in $reqfile - verify version is safe"
      fi
    done
  done < <(find "$SCAN_PATH" \( -name "requirements*.txt" -o -name "pyproject.toml" -o -name "Pipfile" \) 2>/dev/null | head -20)
}

scan_rubygems() {
  local threat_file="$1"

  local num_affected
  num_affected=$(jq '.affected_packages | length' "$threat_file" 2>/dev/null)

  # Check Gemfile.lock
  while IFS= read -r gemlock; do
    [ -z "$gemlock" ] && continue
    for ((i=0; i<num_affected; i++)); do
      local pkg_name
      pkg_name=$(jq -r ".affected_packages[$i].name" "$threat_file" 2>/dev/null)
      local num_versions
      num_versions=$(jq ".affected_packages[$i].compromised_versions | length" "$threat_file" 2>/dev/null)

      for ((j=0; j<num_versions; j++)); do
        local bad_version
        bad_version=$(jq -r ".affected_packages[$i].compromised_versions[$j]" "$threat_file" 2>/dev/null)
        if grep -q "$pkg_name ($bad_version)" "$gemlock" 2>/dev/null; then
          log_compromised "RubyGems: $pkg_name@$bad_version in $gemlock"
        fi
      done
    done
  done < <(find "$SCAN_PATH" -name "Gemfile.lock" 2>/dev/null | head -20)
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    --path) SCAN_PATH="$2"; shift 2 ;;
    --severity) SEVERITY_THRESHOLD="$2"; shift 2 ;;
    --ecosystems) ECOSYSTEMS="$2"; shift 2 ;;
    --ci-mode) CI_MODE=true; shift ;;
    --update) update_threats; exit 0 ;;
    --version) echo "Supply Chain Scanner v${VERSION}"; exit 0 ;;
    --help) usage; exit 0 ;;
    *) echo "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Check dependencies
if ! command -v jq &>/dev/null; then
  log_warn "jq not found. Install it for best results: apt install jq / brew install jq"
  if ! command -v python3 &>/dev/null; then
    echo "ERROR: Either jq or python3 is required."
    exit 1
  fi
fi

# Header
echo ""
echo "=========================================="
echo " Supply Chain Scanner v${VERSION}"
echo " https://github.com/oopsalldev/npm-supply-chain-scanner"
echo "=========================================="
echo ""
echo "Scan path: $(realpath "$SCAN_PATH")"
echo "Ecosystems: $ECOSYSTEMS"
echo "Date: $(date -u '+%Y-%m-%d %H:%M UTC')"
echo ""

# Count threats
THREAT_COUNT=$(find "$THREATS_DIR" -name "*.json" 2>/dev/null | wc -l)
log_info "Loaded $THREAT_COUNT threats from database"
echo ""

# Scan each threat
for threat_file in "$THREATS_DIR"/*.json; do
  [ -f "$threat_file" ] || continue

  local_name=$(jq -r '.name' "$threat_file" 2>/dev/null)
  local_id=$(jq -r '.id' "$threat_file" 2>/dev/null)
  local_severity=$(jq -r '.severity' "$threat_file" 2>/dev/null)
  local_ecosystem=$(basename "$threat_file" .json)

  echo "--- Checking: $local_name ($local_id) [${local_severity}] ---"

  # Run all scan types
  scan_npm "$threat_file"
  scan_malicious_dirs "$threat_file"
  scan_malicious_files "$threat_file"
  scan_file_artifacts "$threat_file"
  scan_network "$threat_file"
  scan_lockfiles "$threat_file"
  scan_html_patterns "$threat_file"

  # Ecosystem-specific scans
  if [[ "$ECOSYSTEMS" == *"pypi"* ]] || [[ "$ECOSYSTEMS" == "all" ]]; then
    scan_pypi "$threat_file"
  fi
  if [[ "$ECOSYSTEMS" == *"rubygems"* ]] || [[ "$ECOSYSTEMS" == "all" ]]; then
    scan_rubygems "$threat_file"
  fi

  ((CLEAN_COUNT++)) || true
  echo ""
done

# Summary
echo "=========================================="
echo " SCAN COMPLETE"
echo "=========================================="
echo ""

if [ "$COMPROMISED_COUNT" -gt 0 ]; then
  echo -e "${RED}STATUS: COMPROMISED${NC}"
  echo "Threats detected: $COMPROMISED_COUNT"
  echo ""
  echo "IMMEDIATE ACTIONS REQUIRED:"
  echo "  1. Isolate affected systems"
  echo "  2. Rotate ALL credentials"
  echo "  3. Review threat details above for specific remediation"
  exit 2
elif [ "$WARNING_COUNT" -gt 0 ]; then
  echo -e "${YELLOW}STATUS: WARNING${NC}"
  echo "Warnings: $WARNING_COUNT"
  echo "Review warnings above and verify manually."
  exit 1
else
  echo -e "${GREEN}STATUS: CLEAN${NC}"
  echo "No known supply chain compromises detected."
  echo "Threats checked: $THREAT_COUNT"
  exit 0
fi
