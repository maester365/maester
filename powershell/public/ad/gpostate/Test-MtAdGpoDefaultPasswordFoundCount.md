#### Test-MtAdGpoDefaultPasswordFoundCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: counts GPOs where a default password is found in the report.

#### Control Type

**Detective**

#### Security Recommendation
- Investigate and remediate GPOs that embed default passwords.

#### How the Test Works
- Retrieves GPO state, filters DefaultPasswordFound, and reports totals and a percentage.

#### Related Tests
- `Test-MtAdGpoDefaultPasswordFoundDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
