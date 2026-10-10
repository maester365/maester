#### Test-MtAdGpoNoPermissionsDetails

 Returns details of GPO reports missing permissions.

#### Why This Test Matters
- Detective control: identifies GPO reports with missing permissions which could enable unintended access.

#### Control Type

**Preventive**

#### Security Recommendation
- Review and remediate missing permissions to ensure proper GPO deployment and ACLs.

#### How the Test Works
- Aggregates GPO reports, checks PermissionsPresent property, and lists reports lacking permissions in a Markdown table.

#### Related Tests
- `Test-MtAdGpoNoPermissionsCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
