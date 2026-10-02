#### Control Type

**Detective**

#### Test-MtAdGpoValidAccountsDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: validates that GPOs reference valid accounts for policy application and auditing purposes.

#### Security Recommendation
- Confirm account references are correct and align with access control policies.

#### How the Test Works
- Retrieves GPO state and lists valid account details found in GPO reports.

#### Related Tests
- `Test-MtAdGpoDefaultPasswordFoundDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
