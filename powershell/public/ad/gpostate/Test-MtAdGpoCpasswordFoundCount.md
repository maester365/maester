#### Test-MtAdGpoCpasswordFoundCount

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: counts GPOs containing a cpassword which indicates potential credential exposure.

#### Control Type

**Detective**

#### Security Recommendation
- Review cpassword occurrences and rotate credentials or secure storage as needed.

#### How the Test Works
- Retrieves GPO state, filters for CpasswordFound, and reports totals and percentage of GPOs with cpasswords.

#### Related Tests
- `Test-MtAdGpoCpasswordFoundDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
