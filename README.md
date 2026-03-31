# Supply Chain Scanner

Open-source, multi-ecosystem supply chain attack scanner. Detects known compromised packages, malware artifacts, C2 connections, and more across your entire dependency tree.

Works as a **CLI tool**, **GitHub Action**, **git hook**, **real-time watcher**, and **Claude Code slash command**.

> This project was built entirely by [Claude Code](https://claude.ai/claude-code) (Anthropic's AI coding agent) during a live security audit session. The AI analyzed a real server for the Axios RAT compromise, then built this scanner to help the community detect all known supply chain attacks.

## Supported Ecosystems

| Ecosystem | Lockfiles | Runtime Check |
|-----------|-----------|---------------|
| npm | package-lock.json, yarn.lock, pnpm-lock.yaml | node_modules scan |
| PyPI | requirements.txt, Pipfile.lock, pyproject.toml | pip show |
| RubyGems | Gemfile.lock | gem list |
| Cargo | Cargo.lock | - |
| Composer | composer.lock | - |
| Go | go.sum | - |
| NuGet | packages.config, .csproj | - |

## Quick Start

### CLI (runs anywhere)

```bash
git clone https://github.com/oopsalldev/npm-supply-chain-scanner
cd npm-supply-chain-scanner

# Scan current directory
./scripts/scan.sh --path /your/project

# Scan entire server
./scripts/scan.sh --path /

# Update threat database
./scripts/scan.sh --update
```

### GitHub Action

Add to `.github/workflows/supply-chain-scan.yml`:

```yaml
name: Supply Chain Scan
on:
  pull_request:
    paths: ['package-lock.json', 'yarn.lock', 'requirements*.txt', 'Gemfile.lock', 'Cargo.lock', 'go.sum']
  schedule:
    - cron: '0 */6 * * *'

jobs:
  scan:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: oopsalldev/npm-supply-chain-scanner@main
        with:
          fail-on-detection: 'true'
```

### Git Hook (pre-commit)

```bash
# Install in any git project
bash <(curl -s https://raw.githubusercontent.com/oopsalldev/npm-supply-chain-scanner/main/scripts/install-hooks.sh)
```

Automatically scans when you commit lockfile changes.

### Real-time Watcher

```bash
# Monitor a directory, scan on lockfile changes
./scripts/watch.sh /your/project 300  # check every 5 minutes

# With Slack/Discord webhook alerts
SUPPLY_CHAIN_WEBHOOK="https://hooks.slack.com/..." ./scripts/watch.sh /your/project
```

### Claude Code Slash Commands

```bash
# Copy commands to your project
mkdir -p .claude/commands && mkdir -p threats
curl -sL https://raw.githubusercontent.com/oopsalldev/npm-supply-chain-scanner/main/.claude/commands/scan.md -o .claude/commands/scan.md
curl -sL https://raw.githubusercontent.com/oopsalldev/npm-supply-chain-scanner/main/.claude/commands/check-package.md -o .claude/commands/check-package.md
curl -sL https://raw.githubusercontent.com/oopsalldev/npm-supply-chain-scanner/main/.claude/commands/add-threat.md -o .claude/commands/add-threat.md
```

Then in Claude Code:

```
/scan                              # Full system scan
/check-package axios               # Check specific package
/check-package axios@1.14.1        # Check specific version
/add-threat https://advisory.url   # Add new threat from article
```

## What It Checks

For every known threat in the database:

1. **Package versions** - Finds all installed versions, compares against compromised versions
2. **Malicious packages** - Detects packages that should never exist (e.g. `plain-crypto-js`, `flatmap-stream`)
3. **File artifacts** - OS-specific malware files left on disk
4. **Network IOCs** - Active connections to known C2 servers
5. **Lockfile analysis** - Compromised shasums in lockfiles
6. **HTML/CDN patterns** - Malicious CDN references (e.g. polyfill.io)
7. **Ecosystem-specific** - pip packages, gems, crates, etc.

## Threat Database

Community-maintained JSON files in `threats/`. Currently tracking **15 major attacks** across 3 ecosystems:

### npm

| ID | Name | Year | Severity | What It Does |
|----|------|------|----------|--------------|
| NSCS-2025-003 | Shai-Hulud Worm | 2025 | Critical | Self-replicating worm, steals cloud tokens, 1000+ packages |
| NSCS-2025-002 | Nx Credential Stealer | 2025 | Critical | Steals credentials, AWS admin takeover in 72h |
| NSCS-2025-001 | Axios RAT | 2025 | Critical | Cross-platform remote access trojan |
| NSCS-2024-003 | Polyfill.io CDN Hijack | 2024 | Critical | 380K+ websites injected with malware |
| NSCS-2024-002 | Lottie Player Drainer | 2024 | Critical | Injects crypto wallet drainer into websites |
| NSCS-2024-001 | Solana web3.js Backdoor | 2024 | Critical | Exfiltrates private keys, $160K stolen |
| NSCS-2021-002 | coa & rc DanaBot | 2021 | Critical | Drops DanaBot banking trojan |
| NSCS-2021-001 | ua-parser-js Miner | 2021 | Critical | Cryptominer + password stealer |
| NSCS-2018-001 | event-stream Backdoor | 2018 | High | Targeted Copay bitcoin wallet theft |

### PyPI (Python)

| ID | Name | Year | Severity | What It Does |
|----|------|------|----------|--------------|
| NSCS-2024-005 | Ultralytics YOLO Miner | 2024 | Critical | XMRig cryptominer via GitHub Actions cache poisoning |
| NSCS-2024-004 | Colorama Typosquats | 2024 | High | Fade Stealer: browser creds, Discord, crypto wallets |
| NSCS-2022-002 | PyTorch torchtriton | 2022 | Critical | Dependency confusion, steals SSH keys & env vars |
| NSCS-2022-001 | CTX Account Takeover | 2022 | Critical | Exfiltrates all environment variables |

### RubyGems

| ID | Name | Year | Severity | What It Does |
|----|------|------|----------|--------------|
| NSCS-2019-002 | bootstrap-sass Backdoor | 2019 | Critical | Cookie-based RCE on Rails servers |
| NSCS-2019-001 | rest-client Backdoor | 2019 | Critical | Credential theft + remote code execution |

### Threat file format

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
      "compromised_versions": ["1.2.3"],
      "safe_versions": ["1.2.2", "1.2.4"]
    }
  ],
  "c2_servers": [{ "domain": "evil.com", "ip": "1.2.3.4", "port": 443 }],
  "file_artifacts": { "linux": ["/tmp/malware"], "macos": [], "windows": [] },
  "malicious_indicators": {
    "directories": ["malicious-pkg"],
    "files": ["evil.js"],
    "network_patterns": ["evil.com"]
  },
  "remediation": ["Step 1", "Step 2"]
}
```

## Staying Updated

```bash
# Update threat database
cd npm-supply-chain-scanner && git pull

# Or use the built-in updater
./scripts/scan.sh --update
```

Star and watch this repo - we push updates within hours of new attack disclosures.

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). The fastest way to add a new threat:

```
/add-threat https://url-to-advisory
```

Or open an issue with the advisory URL.

## License

MIT (c) 2026 [oops.zone](https://oops.zone)

---

Built with [Claude Code](https://claude.ai/claude-code) by [oops.zone](https://oops.zone)
