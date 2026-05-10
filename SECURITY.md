## Security policy

### Supported versions

Maester is released through the PowerShell Gallery. Security fixes are provided
for the latest published release and the current preview release when a preview
is available.

If you are using an older version, update to the latest release before reporting
a vulnerability unless the issue is also reproducible in the latest version.

### Reporting a vulnerability

Please do not report security vulnerabilities in public issues, pull requests,
or discussions.

Use GitHub private vulnerability reporting for this repository:

https://github.com/maester365/maester/security/advisories/new

Include enough detail for maintainers to reproduce and assess the vulnerability:

- Affected Maester version or commit.
- A description of the vulnerability and expected impact.
- Reproduction steps or proof-of-concept details.
- Any known affected Microsoft 365, PowerShell, or runtime configuration.
- Whether the issue is already public or shared with other parties.

### Disclosure process

The Maester maintainers will acknowledge vulnerability reports as quickly as
possible and will coordinate investigation, remediation, and disclosure with the
reporter.

Expected handling:

- Initial acknowledgment target: within 7 days.
- Status update target: within 30 days when the investigation remains open.
- Coordinated disclosure target: after a fix or mitigation is available, or on a
  mutually agreed timeline.

Please give maintainers a reasonable opportunity to investigate and publish a
fix before publicly disclosing vulnerability details.

### Scope

Security reports should focus on vulnerabilities in Maester code, workflows,
release artifacts, documentation that could lead to unsafe operation, or bundled
dependencies.

Examples of in-scope reports include:

- Injection, spoofing, or tampering issues in Maester reports or exported data.
- Vulnerable dependency paths that are reachable in supported Maester usage.
- GitHub Actions or release-process issues that could affect published artifacts.
- Unsafe handling of tenant, identity, or test-result data.

Out-of-scope reports include:

- Vulnerabilities only present in unsupported Maester versions.
- Findings that require unsupported local modifications.
- General Microsoft 365 configuration findings that are not caused by Maester.
- Denial-of-service reports that rely only on excessive local resource use
  without a security boundary impact.

### Public tracking

After a fix is available, maintainers may publish a GitHub Security Advisory,
release notes, or other public guidance with appropriate credit to the reporter
unless credit is declined.
