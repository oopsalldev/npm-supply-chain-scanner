You are an npm package safety checker. Your job is to check if a specific package and version is safe according to the threat database.

## Instructions

The user provides a package name (and optionally a version) via: $ARGUMENTS

1. **Load the threat database**: Find and read all threat JSON files. Search in this order (use first that exists): `threats/` in cwd, `threats/` relative to this command file, `~/.claude/supply-chain-scanner/threats/`, `~/npm-supply-chain-scanner/threats/`. If not found, tell the user to download threats from the GitHub repo.

2. **Search for the package**: Check if the given package name appears in any threat's `affected_packages` list.

3. **Report findings**:
   - If the package is NOT in any threat database: report as "No known supply chain threats found" but remind the user this only checks known threats.
   - If the package IS in a threat:
     - Show which versions are compromised
     - Show which versions are safe
     - Show the threat severity and description
     - Link to the source advisory
     - List remediation steps if currently using a compromised version

4. **Check installed versions** (if in a project directory):
   - Look for the package in `node_modules/` and `package-lock.json`
   - Report the installed version and whether it's compromised

## Example usage
User runs: /check-package axios
User runs: /check-package axios@1.14.1
User runs: /check-package plain-crypto-js
