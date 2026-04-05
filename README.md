# Supply Chain Scanner

Open-source, multi-ecosystem supply chain attack scanner. Detects known compromised packages, malware artifacts, C2 connections, and more across your entire dependency tree.

Works as a **CLI tool**, **GitHub Action**, **git hook**, **real-time watcher**, and **Claude Code slash command**.

> This project was built entirely by [Claude Code](https://claude.ai/claude-code) (Anthropic's AI coding agent) during a live security audit session. The AI analyzed a real server for the Axios RAT compromise, then built this scanner to help the community detect all known supply chain attacks.

## Get Started in 30 Seconds

**CLI** -- scan any project or server:
```bash
git clone https://github.com/oopsalldev/npm-supply-chain-scanner && cd npm-supply-chain-scanner
./scripts/scan.sh --path /your/project
```

**GitHub Action** -- add to any workflow:
```yaml
- uses: oopsalldev/npm-supply-chain-scanner@main
  with:
    fail-on-detection: 'true'
```

**Claude Code** -- interactive scan:
```
/scan
```

See [full usage details](#quick-start) below for all modes including git hooks, real-time watcher, and more options.

---

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

Community-maintained JSON files in `threats/`. Currently tracking **25 major attacks** across 7 ecosystems:

### npm (9 threats)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2025-003 | Shai-Hulud Worm | 2025 | Self-replicating worm, cloud token stealer, 1000+ packages |
| NSCS-2025-002 | Nx Credential Stealer | 2025 | AWS admin takeover in 72h via stolen creds |
| NSCS-2025-001 | Axios RAT | 2025 | Cross-platform remote access trojan |
| NSCS-2024-003 | Polyfill.io CDN Hijack | 2024 | 380K+ websites injected, North Korea linked |
| NSCS-2024-002 | Lottie Player Drainer | 2024 | Web3 wallet drainer via Ace Drainer DaaS |
| NSCS-2024-001 | Solana web3.js | 2024 | Private key exfiltration, $160K stolen |
| NSCS-2021-002 | coa & rc DanaBot | 2021 | Banking trojan via DLL |
| NSCS-2021-001 | ua-parser-js | 2021 | XMRig cryptominer + password stealer |
| NSCS-2018-001 | event-stream | 2018 | Targeted Copay bitcoin wallet theft |

### PyPI (5 threats)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2026-001 | TeamPCP (LiteLLM + Telnyx) | 2026 | Cascading attack: K8s lateral movement, systemd backdoor |
| NSCS-2024-005 | Ultralytics YOLO | 2024 | XMRig cryptominer via GitHub Actions poisoning |
| NSCS-2024-004 | Colorama Typosquats | 2024 | Fade Stealer: browser creds, Discord, crypto wallets |
| NSCS-2022-002 | PyTorch torchtriton | 2022 | Dependency confusion, SSH key exfiltration |
| NSCS-2022-001 | CTX Account Takeover | 2022 | Exfiltrates all environment variables |

### RubyGems (3 threats)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2019-003 | strong_password | 2019 | Cookie-based RCE in Rails production |
| NSCS-2019-002 | bootstrap-sass | 2019 | Cookie-based RCE on Rails servers |
| NSCS-2019-001 | rest-client | 2019 | Credential theft + remote code execution |

### Cargo/Rust (2 threats)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2025-004 | faster_log | 2025 | Steals Ethereum/Solana private keys from source |
| NSCS-2022-003 | rustdecimal | 2022 | Deploys Mythic Poseidon agent in GitLab CI |

### Go Modules (3 threats)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2026-002 | Fake golang.org/x/crypto | 2026 | Intercepts SSH passwords, Rekoobe backdoor |
| NSCS-2025-005 | Disk Wiper Modules | 2025 | Overwrites /dev/sda - destroys Linux systems |
| NSCS-2021-003 | boltdb-go | 2021 | Persistent backdoor, 3+ years undetected |

### Composer/PHP (1 threat)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2024-006 | Fake Laravel Packages | 2024 | Full RAT: remote shell, file exfil, screenshots |

### NuGet/.NET (2 threats)

| ID | Name | Year | What It Does |
|----|------|------|--------------|
| NSCS-2024-007 | JIT Hook Identity Stealer | 2024 | JIT compiler hooks, ASP.NET auth backdoor |
| NSCS-2023-001 | PLC Sabotage (shanhai666) | 2023 | Logic bombs sabotaging Siemens PLCs and databases |

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
