#### Test-MtAdGpoNoPermissionsDetails

 Returns details of GPO reports missing permissions.

#### Why This Test Matters
- Detective control: identifies GPO reports with missing permissions which could enable unintended access.

#### Control Type

**Preventive**

#### Security Recommendation
- Review and remediate missing permissions to ensure proper GPO deployment and ACLs.

#### How the Test Works
- Aggregates GPO reports and lists the ones whose DACL has no entries (PermissionsPresent is false) in a Markdown table.
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.

#### Related Tests
- `Test-MtAdGpoNoPermissionsCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
