#### Test-MtAdGpoComputerSettingsDisabledDetails

 Returns details of GPOs where computer settings are disabled.

#### Why This Test Matters
- Detective control: lists GPOs where computer settings are disabled which can affect machine-level policy delivery.

#### Control Type

**Operational**

#### Security Recommendation
- Review computer-disabled GPOs and confirm they are intentional.

#### How the Test Works
- Analyzes GPO state to extract GpoStatus ComputerDisabled details and renders a detailed table.

#### Related Tests
- `Test-MtAdGpoComputerSettingsDisabledDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
