## What this PR does

<!-- Describe your changes in 1-3 sentences. -->


## Type of change

- [ ] New threat added to database
- [ ] Bug fix
- [ ] New feature or enhancement
- [ ] Documentation update
- [ ] New ecosystem support
- [ ] CI / workflow change

## Testing done

<!-- Describe how you tested your changes. -->

- [ ] Ran `./scripts/scan.sh --path <test-dir>` successfully
- [ ] Tested against a project with the relevant lockfiles
- [ ] Verified scanner output is correct

## Checklist

- [ ] Threat JSON is valid (`jq . threats/your-file.json` passes)
- [ ] Threat follows the naming convention (`ecosystem-name-year.json`)
- [ ] Compromised versions are specific (not ranges)
- [ ] Source/advisory URL is included
- [ ] Remediation steps are included
- [ ] Scan tested end-to-end with the new threat
- [ ] Documentation updated (if applicable)
- [ ] No secrets or credentials in the diff
