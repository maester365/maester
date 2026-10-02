#### Test-MtAdGpoDefaultPasswordFoundDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: verifies whether any GPO reports contain a default password and highlights those findings for remediation.
- In security terms, default passwords in GPOs are a common misconfiguration risk that attackers could exploit.

#### Control Type

**Detective**

#### Security Recommendation
- Review GPOs listed in the report and replace default passwords with secure, unique credentials per policy. Remove any passwords that are no longer needed.

#### How the Test Works
- Invokes Get-MtADGpoState to fetch GPO state data, then filters GPO reports where DefaultPasswordFound is true.
- Builds a Markdown table of GPO name and the DefaultPasswordFound flag, plus a summary line with counts.

#### Related Tests
- `Test-MtAdGpoDefaultPasswordFoundCount` - Counts how many GPOs have a default password.

#### Related links
- [Microsoft Learn - Group Policy security best practices](https://learn.microsoft.com/en-us/windows-server/group-policy/intro-and-overview)
- ANSSI checkpoint: https://www.anssi.gouv.fr/
