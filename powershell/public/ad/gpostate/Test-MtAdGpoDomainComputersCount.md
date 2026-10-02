#### Control Type

**Detective**

#### Test-MtAdGpoDomainComputersCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: counts GPO reports missing Domain Computers attributes which affects policy targeting.

#### Security Recommendation
- Validate whether Domain Computers should be included for GPO application and adjust as needed.

#### How the Test Works
- Retrieves GPO state and counts reports with HasDomainComputers set to false or missing.

#### Related Tests
- `Test-MtAdGpoNoDomainComputersCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
