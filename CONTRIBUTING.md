# Contributing

Supply chain attacks affect everyone. Help us keep the community safe.

## Table of Contents

- [Development Setup](#development-setup)
- [Adding a New Threat](#adding-a-new-threat)
- [Adding Support for a New Ecosystem](#adding-support-for-a-new-ecosystem)
- [Testing Your Changes](#testing-your-changes)
- [PR Workflow](#pr-workflow)
- [Threat Severity Guidelines](#threat-severity-guidelines)

## Development Setup

```bash
# Clone the repo
git clone https://github.com/oopsalldev/npm-supply-chain-scanner
cd npm-supply-chain-scanner

# Verify the scanner runs
./scripts/scan.sh --path .

# (Optional) Install the git hook for local development
bash scripts/install-hooks.sh
```

Requirements:
- **bash** 4.0+ (macOS ships 3.2 -- use `brew install bash` if needed)
- **jq** for JSON processing (`apt install jq` / `brew install jq`)
- **curl** for update checks
- Standard POSIX tools: `grep`, `find`, `awk`, `sed`

No build step, no dependencies, no runtimes. The scanner is pure bash.

## Adding a New Threat

This is the most common contribution. Each threat is a single JSON file in `threats/`.

### The fast way

Use the Claude Code slash command:

```
/add-threat https://url-to-advisory-article
```

This reads the advisory, extracts all relevant data, and creates a properly formatted JSON file.

### Manual creation

Create a file in `threats/` following the naming convention:

```
threats/<ecosystem>-<short-name>-<year>.json
```

Examples: `axios-rat-2025.json`, `pypi-colorama-typosquat-2024.json`, `cargo-rustdecimal-2022.json`

For npm threats that are not ecosystem-prefixed (because npm was the original scope), either format is acceptable: `axios-rat-2025.json` or `npm-axios-rat-2025.json`.

### JSON schema reference

Every field explained:

```json
{
  "id": "NSCS-YYYY-NNN",
  "name": "Human-readable name",
  "severity": "critical",
  "date_discovered": "2026-01-15",
  "source": "https://advisory-url",
  "description": "What the attack does",
  "affected_packages": [
    {
      "name": "package-name",
      "compromised_versions": ["1.2.3", "1.2.4"],
      "safe_versions": ["1.2.2", "1.2.5"],
      "shasum": {
        "1.2.3": "abc123..."
      },
      "note": "Optional context about this specific package"
    }
  ],
  "c2_servers": [
    {
      "domain": "evil.com",
      "ip": "1.2.3.4",
      "port": 443,
      "endpoint": "/callback"
    }
  ],
  "file_artifacts": {
    "linux": ["/tmp/malware"],
    "macos": ["/Library/Caches/com.apple.act.mond"],
    "windows": ["%PROGRAMDATA%\\wt.exe"]
  },
  "malicious_indicators": {
    "directories": ["malicious-pkg"],
    "files": ["evil.js"],
    "network_patterns": ["evil.com"]
  },
  "remediation": [
    "Step 1: Remove compromised package",
    "Step 2: Rotate all credentials",
    "Step 3: Audit system for persistence"
  ]
}
```

**Field details:**

| Field | Required | Description |
|-------|----------|-------------|
| `id` | Yes | Unique ID in format `NSCS-YYYY-NNN`. Use the next available number for the year. |
| `name` | Yes | Human-readable attack name. |
| `severity` | Yes | One of: `critical`, `high`, `medium`, `low`. See [severity guidelines](#threat-severity-guidelines). |
| `date_discovered` | Yes | ISO date when the attack was publicly disclosed. |
| `source` | Yes | URL to the advisory, blog post, or CVE. |
| `description` | Yes | One-paragraph summary of what the attack does. |
| `affected_packages` | Yes | Array of affected packages with specific compromised versions. |
| `affected_packages[].name` | Yes | Exact package name as it appears in the registry. |
| `affected_packages[].compromised_versions` | Yes | Array of specific version strings. Never use ranges. |
| `affected_packages[].safe_versions` | No | Known safe versions before/after the compromise. |
| `affected_packages[].shasum` | No | SHA sums of compromised tarballs for lockfile matching. |
| `affected_packages[].note` | No | Extra context (e.g., "entirely malicious, should never exist"). |
| `c2_servers` | No | Array of known command-and-control infrastructure. |
| `file_artifacts` | No | OS-specific file paths dropped by the malware. |
| `malicious_indicators` | No | Directories, files, and network patterns to scan for. |
| `remediation` | Yes | Ordered steps to recover from the compromise. |

### Naming the ID

Check existing IDs to find the next available number:

```bash
grep -h '"id"' threats/*.json | sort
```

IDs are sequential within a year: `NSCS-2026-001`, `NSCS-2026-002`, etc.

### Validate your JSON

```bash
# Check syntax
jq . threats/your-file.json

# Verify required fields exist
jq 'has("id", "name", "severity", "affected_packages", "remediation")' threats/your-file.json
```

## Adding Support for a New Ecosystem

The scanner is designed to be ecosystem-agnostic. To add a new ecosystem:

1. **Update `scripts/scan.sh`** -- add a detection function that:
   - Identifies the ecosystem's lockfiles (e.g., `mix.lock` for Elixir)
   - Extracts installed package names and versions
   - Compares against the threat database

2. **Update `action.yml`** -- add the ecosystem name to the `ecosystems` input description.

3. **Add at least one threat** -- create a JSON file in `threats/` for a known attack in that ecosystem.

4. **Update documentation** -- add the ecosystem to the table in `README.md` and mention it in this file.

The key function to study is the main scan loop in `scan.sh`. Each ecosystem follows the same pattern: find lockfiles, extract packages, check against threats.

## Testing Your Changes

### Testing a new threat

```bash
# Validate JSON
jq . threats/your-new-threat.json

# Run the scanner against a test project that has the affected package
./scripts/scan.sh --path /path/to/test/project

# Run against a clean project to verify no false positives
./scripts/scan.sh --path /path/to/clean/project

# Test a specific ecosystem
./scripts/scan.sh --path /path/to/project --ecosystems npm
```

### Testing scanner changes

```bash
# Full scan of the scanner repo itself (should be clean)
./scripts/scan.sh --path .

# Test CI mode output
./scripts/scan.sh --path /path/to/project --ci-mode

# Test severity filtering
./scripts/scan.sh --path /path/to/project --severity critical

# Test the watcher
./scripts/watch.sh /path/to/project 10  # 10-second interval for testing
```

### Testing the GitHub Action locally

You can approximate the Action behavior:

```bash
# Simulate what the Action does
chmod +x scripts/scan.sh
./scripts/scan.sh --path . --severity high --ecosystems all --ci-mode
```

## PR Workflow

1. **Fork** the repository.
2. **Create a branch** from `main`:
   ```bash
   git checkout -b add-threat-xyz
   # or: git checkout -b fix-pypi-detection
   ```
3. **Make your changes** and test them locally.
4. **Validate** all threat JSON files:
   ```bash
   for f in threats/*.json; do jq . "$f" > /dev/null || echo "INVALID: $f"; done
   ```
5. **Commit** with a clear message:
   ```
   Add threat: package-name supply chain attack (NSCS-2026-003)
   Fix: PyPI lockfile detection on Windows
   ```
6. **Open a PR** against `main`. Fill out the PR template.
7. A maintainer will review and merge. For new threats, we aim to merge within hours.

### What makes a good PR

- One logical change per PR (one threat, one bug fix, one feature).
- Threat PRs include the source/advisory URL.
- Code PRs include before/after test output.
- No unrelated formatting or whitespace changes.

## Threat Severity Guidelines

Use these criteria when assigning the `severity` field:

### critical

- Active remote code execution or system compromise
- Data exfiltration (credentials, private keys, tokens)
- Self-replicating or worm-like behavior
- Affects widely-used packages (>1M weekly downloads)
- Active exploitation confirmed in the wild

Examples: Axios RAT, Shai-Hulud worm, event-stream (targeted wallet theft)

### high

- Known malicious payload with significant impact
- Cryptominer deployment
- Backdoor installation
- Credential harvesting
- Affects moderately popular packages

Examples: ua-parser-js cryptominer, PyTorch torchtriton, coa/rc DanaBot

### medium

- Limited targeting or narrow conditions for exploitation
- Typosquats with moderate download counts
- Attacks requiring specific environment conditions
- Dependency confusion with limited blast radius

Examples: Colorama typosquats, CTX account takeover

### low

- Proof-of-concept or researcher demonstrations
- Packages removed before significant downloads
- Theoretical risk with no confirmed exploitation
- Informational entries for awareness

When in doubt, err on the side of higher severity. It is better to warn users about a potential medium threat than to underrate an active attack.
