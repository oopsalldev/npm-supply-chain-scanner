# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **DO NOT** open a public GitHub issue
2. Use [GitHub Private Vulnerability Reporting](https://github.com/oopsalldev/npm-supply-chain-scanner/security/advisories/new)
3. Or email: security@oops.zone

We will respond within 48 hours and aim to release a fix within 7 days.

## Scope

This project is a **scanner**, not a runtime dependency. However, we take seriously:

- False negatives (failing to detect a known compromised package)
- Incorrect threat data (wrong versions, wrong IOCs)
- Vulnerabilities in the scan scripts themselves
- Potential for the scanner to be used as an attack vector

## Threat Database Integrity

The `threats/` directory contains IOCs (Indicators of Compromise) including C2 domains and IPs. If you notice:

- A threat entry with incorrect data
- A missing threat that should be tracked
- A false positive pattern that flags legitimate packages

Please open a regular issue or PR. These are not security vulnerabilities.

## Supported Versions

| Version | Supported |
|---------|-----------|
| main branch | Yes |
| All others | No |

We only maintain the `main` branch. Always pull the latest version.
