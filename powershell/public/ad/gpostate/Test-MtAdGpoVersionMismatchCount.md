#### Test-MtAdGpoVersionMismatchCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: flags GPOs that have a version mismatch which could affect policy consistency across machines.

#### Control Type

**Detective**

#### Security Recommendation
- Review mismatched GPOs and align versions with baseline configurations.

#### How the Test Works
- Pulls GPO state, filters HasVersionMismatch, counts total/mismatched and computes a mismatch ratio.

#### Related Tests
- `Test-MtAdGpoVersionMismatchDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
