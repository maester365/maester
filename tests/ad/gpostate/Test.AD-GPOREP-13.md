#### Test-MtAdGpoDisabledLinkDetails

 Returns details of GPOs with disabled GPO links.

#### Why This Test Matters
- Detective control: checks for GPOs with disabled links to identify potential misconfigurations that could affect policy delivery.
- Disabled links can lead to unexpected policy application gaps.

#### Control Type

**Operational**

#### Security Recommendation
- Review and re-enable intentional GPO links or remove unused GPOs to restore intended policy application.

#### How the Test Works
- Retrieves GPO state via Get-MtADGpoState, filters GPOReports for DisabledLinks greater than 0, and renders a Markdown table with the results.

#### Related Tests
- `Test-MtAdGpoDisabledLinkCount` - Count of disabled links across GPOs.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
