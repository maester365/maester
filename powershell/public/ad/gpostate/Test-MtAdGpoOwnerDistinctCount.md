#### Test-MtAdGpoOwnerDistinctCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Operational control: assesses diversity of GPO owners which can highlight unusual configurations or omissions.

#### Control Type

**Operational**

#### Security Recommendation
- If many owners are identical or blank, review GPO creation practices to ensure proper ownership.

#### How the Test Works
- Retrieves GPO state, extracts Owner fields, computes distinct non-empty owners, and reports the count.

#### Related Tests
- `Test-MtAdGpoOwnerDetails` - summarizes owners per GPOs.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
