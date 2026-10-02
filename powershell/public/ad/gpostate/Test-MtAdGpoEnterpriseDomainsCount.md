#### Control Type

**Detective**

#### Test-MtAdGpoEnterpriseDomainsCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: counts GPO reports related to Enterprise Domains presence which can influence domain-wide policy scope.

#### Security Recommendation
- Ensure Enterprise Domain Controllers are covered by GPOs as intended or adjust configuration.

#### How the Test Works
- Analyzes GPO state for enterprise domain controller coverage and reports totals.

#### Related Tests
- `Test-MtAdGpoStateTotalCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
