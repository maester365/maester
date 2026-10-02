#### Test-MtAdGpoCpasswordFoundDetails

[One-sentence description of what this test checks]

#### Why This Test Matters
- Detective control: detects GPOs that contain a Cpassword which could be exploited if leaked.
- Cpasswords expose sensitive credentials and should be protected.

#### Control Type

**Detective**

#### Security Recommendation
- Rotate or remove the cpasswords where necessary and apply proper protection controls.

#### How the Test Works
- Uses Get-MtADGpoState to obtain GPO data, filters for reports where CpasswordFound is true, and formats a Markdown table.

#### Related Tests
- `Test-MtAdGpoCpasswordFoundCount` - counts GPOs with cpasswords.

#### Related links
- [Microsoft Learn - Group Policy security](https://learn.microsoft.com/en-us/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
