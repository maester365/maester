#### Control Type

**Detective**

#### Test-MtAdGpoNoDomainComputersCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: identifies GPO reports missing Domain Computers which could impact scope or applicability.

#### Security Recommendation
- Verify whether Domain Computers should be included and adjust GpoReports as needed to reflect accurate targeting.

#### How the Test Works
- Reads GPO state, locates GpoReports, filters for reports with HasDomainComputers false or missing, and reports counts and samples.

#### Related Tests
- `Test-MtAdGpoNoDomainComputersCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
