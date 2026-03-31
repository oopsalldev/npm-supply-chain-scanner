# Contributing

Supply chain attacks affect everyone. Help us keep the community safe.

## Adding a new threat

The fastest way: use the Claude Code slash command:

```
/add-threat https://url-to-advisory-article
```

Or manually create a JSON file in `threats/`:

```json
{
  "id": "NSCS-YYYY-NNN",
  "name": "Human-readable name",
  "severity": "critical|high|medium|low",
  "date_discovered": "YYYY-MM-DD",
  "source": "https://advisory-url",
  "description": "What the attack does",
  "affected_packages": [...],
  "c2_servers": [...],
  "file_artifacts": { "linux": [], "macos": [], "windows": [] },
  "malicious_indicators": { "directories": [], "files": [], "network_patterns": [] },
  "remediation": [...]
}
```

## Supported ecosystems

We track threats across all major package managers:

- **npm** (JavaScript/TypeScript)
- **PyPI** (Python)
- **RubyGems** (Ruby)
- **Cargo** (Rust)
- **Composer** (PHP)
- **Go Modules** (Go)
- **NuGet** (.NET)

## Guidelines

- One JSON file per attack campaign
- Include source URLs for verification
- Add specific compromised versions (not ranges)
- Include IOCs: C2 domains/IPs, file artifacts, network patterns
- Write clear remediation steps
- Test your JSON is valid: `jq . threats/your-file.json`

## Reporting a new attack

If you've discovered a supply chain compromise:

1. Open an issue with the advisory URL
2. Tag it with `new-threat`
3. We'll add it to the database within hours

## Code contributions

For scanner improvements:

1. Fork the repo
2. Create a feature branch
3. Test with `./scripts/scan.sh --path /your/test/dir`
4. Submit a PR
