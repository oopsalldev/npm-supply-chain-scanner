#!/usr/bin/env bash
# Install git hooks for supply chain scanning
# https://github.com/oopsalldev/npm-supply-chain-scanner
# License: MIT (c) 2026 oops.zone

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCANNER_DIR="$(dirname "$SCRIPT_DIR")"

# Find the git root
GIT_ROOT=$(git rev-parse --show-toplevel 2>/dev/null)
if [ -z "$GIT_ROOT" ]; then
  echo "Error: Not in a git repository."
  exit 1
fi

HOOKS_DIR="$GIT_ROOT/.git/hooks"

echo "Installing supply chain scanner git hooks..."
echo "Git root: $GIT_ROOT"
echo ""

# Pre-commit hook: scan lockfile changes
cat > "$HOOKS_DIR/pre-commit-supply-chain" << HOOK
#!/usr/bin/env bash
# Supply chain scanner pre-commit hook

CHANGED_LOCKFILES=\$(git diff --cached --name-only | grep -E "(package-lock\.json|yarn\.lock|pnpm-lock\.yaml|requirements.*\.txt|Pipfile\.lock|Gemfile\.lock|Cargo\.lock|composer\.lock|go\.sum)" || true)

if [ -n "\$CHANGED_LOCKFILES" ]; then
  echo "Lockfile changed - running supply chain scan..."
  if [ -f "$SCANNER_DIR/scripts/scan.sh" ]; then
    bash "$SCANNER_DIR/scripts/scan.sh" --path "$GIT_ROOT" 2>&1
    exit_code=\$?
    if [ \$exit_code -eq 2 ]; then
      echo ""
      echo "BLOCKED: Compromised dependency detected. Fix before committing."
      exit 1
    fi
  fi
fi
HOOK

chmod +x "$HOOKS_DIR/pre-commit-supply-chain"

# Append to pre-commit if it exists, or create it
if [ -f "$HOOKS_DIR/pre-commit" ]; then
  if ! grep -q "pre-commit-supply-chain" "$HOOKS_DIR/pre-commit"; then
    echo "" >> "$HOOKS_DIR/pre-commit"
    echo "# Supply chain scanner" >> "$HOOKS_DIR/pre-commit"
    echo "bash \"$HOOKS_DIR/pre-commit-supply-chain\"" >> "$HOOKS_DIR/pre-commit"
  fi
else
  cat > "$HOOKS_DIR/pre-commit" << HOOK
#!/usr/bin/env bash
bash "$HOOKS_DIR/pre-commit-supply-chain"
HOOK
  chmod +x "$HOOKS_DIR/pre-commit"
fi

echo "Installed: pre-commit hook (scans on lockfile changes)"
echo ""
echo "Done! The scanner will automatically run when you commit lockfile changes."
