# NPM Supply Chain Scanner for Claude Code

A community-maintained threat database and Claude Code skill set for detecting npm supply chain attacks on your servers and projects.

## What is this?

When npm packages get compromised (like the [Axios RAT incident](https://www.stepsecurity.io/blog/axios-compromised-on-npm-malicious-versions-drop-remote-access-trojan)), this tool helps you quickly scan your systems for known threats using Claude Code slash commands.

## Features

- `/scan` - Full system scan for all known supply chain threats
- `/add-threat` - Add new threats to the database from advisory URLs
- `/check-package` - Quick check if a specific package/version is compromised

## Installation

### Option 1: Add as a git submodule (recommended)

```bash
cd your-project
git submodule add https://github.com/oopszone/npm-supply-chain-scanner .claude/supply-chain-scanner
```

Then copy or symlink the commands:

```bash
# Copy commands to your project's Claude Code commands
cp -r .claude/supply-chain-scanner/.claude/commands/* .claude/commands/
```

### Option 2: Clone and symlink globally

```bash
# Clone the repo
git clone https://github.com/oopszone/npm-supply-chain-scanner ~/npm-supply-chain-scanner

# Symlink commands to your project
ln -s ~/npm-supply-chain-scanner/.claude/commands/scan.md /your-project/.claude/commands/scan.md
ln -s ~/npm-supply-chain-scanner/.claude/commands/check-package.md /your-project/.claude/commands/check-package.md
ln -s ~/npm-supply-chain-scanner/.claude/commands/add-threat.md /your-project/.claude/commands/add-threat.md
```

### Option 3: Quick one-liner per project

```bash
# In your project root
mkdir -p .claude/commands
curl -sL https://raw.githubusercontent.com/oopszone/npm-supply-chain-scanner/main/.claude/commands/scan.md -o .claude/commands/scan.md
curl -sL https://raw.githubusercontent.com/oopszone/npm-supply-chain-scanner/main/.claude/commands/check-package.md -o .claude/commands/check-package.md
curl -sL https://raw.githubusercontent.com/oopszone/npm-supply-chain-scanner/main/.claude/commands/add-threat.md -o .claude/commands/add-threat.md
mkdir -p threats
curl -sL https://raw.githubusercontent.com/oopszone/npm-supply-chain-scanner/main/threats/axios-rat-2025.json -o threats/axios-rat-2025.json
```

## Usage

Open Claude Code in your project and run:

```
/scan              # Full system scan against all known threats
/check-package axios        # Check a specific package
/check-package axios@1.14.1 # Check a specific version
/add-threat https://advisory-url.com  # Add a new threat from an article
```

### Example scan output

```
## NPM Supply Chain Scan Report
Date: 2026-03-31
System: my-server / Linux
Threats checked: 9

### Axios RAT (NSCS-2025-001)
Severity: critical | Status: CLEAN
### Nx Credential Stealer (NSCS-2025-002)
Severity: critical | Status: CLEAN
### Shai-Hulud Worm (NSCS-2025-003)
Severity: critical | Status: WARNING - bun_environment.js found
...

Overall: 8 CLEAN, 1 WARNING - review recommended
```

## Threat Database

Threats are stored as JSON files in the `threats/` directory. Each file contains:

- Affected package names and compromised versions
- C2 server indicators (domains, IPs, ports)
- File system artifacts per OS
- Network patterns to check
- Remediation steps

### Current threats

| ID | Name | Severity | Packages | Type |
|----|------|----------|----------|------|
| NSCS-2025-003 | Shai-Hulud Worm | Critical | @asyncapi/specs, PostHog, Postman + 1000s | Cloud token stealer, self-replicating worm |
| NSCS-2025-002 | Nx Credential Stealer | Critical | nx, @nx/devkit, @nx/js, @nx/workspace + more | Credential stealer, AWS takeover |
| NSCS-2025-001 | Axios RAT | Critical | axios@1.14.1, axios@0.30.4 | Remote access trojan |
| NSCS-2024-003 | Polyfill.io CDN Hijack | Critical | polyfill.io (CDN, not npm) | Malware injection via CDN |
| NSCS-2024-002 | Lottie Player Drainer | Critical | @lottiefiles/lottie-player | Crypto wallet drainer |
| NSCS-2024-001 | Solana web3.js Backdoor | Critical | @solana/web3.js | Private key stealer |
| NSCS-2021-002 | coa & rc DanaBot | Critical | coa, rc | Banking trojan |
| NSCS-2021-001 | ua-parser-js Miner | Critical | ua-parser-js | Cryptominer + password stealer |
| NSCS-2018-001 | event-stream Backdoor | High | event-stream, flatmap-stream | Targeted bitcoin theft |

## Contributing

Found a new npm supply chain attack? Help the community:

1. Fork this repo
2. Use `/add-threat <advisory-url>` to generate the threat JSON, or create one manually in `threats/`
3. Submit a PR

Or open an issue with the advisory URL and we'll add it.

## Staying Updated

Star and watch this repo to get notified when new threats are added. We aim to add new threats within hours of public disclosure.

```bash
# Update your local copy
cd npm-supply-chain-scanner
git pull
```

## License

MIT - Use freely, stay safe.

## Maintained by

[oops.zone](https://oops.zone) - Server management and security tools.
