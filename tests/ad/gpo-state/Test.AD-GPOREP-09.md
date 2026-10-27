#### Control Type

**Operational**

#### Test-MtAdGpoInheritedPermissionsCount

 Counts GPO reports with inherited permissions.

#### Why This Test Matters
- Detective control: checks for inherited permissions in GPOs which may lead to broader access than intended.

#### Security Recommendation
- Review inherited permissions and consider removing inheritance where not needed.

#### How the Test Works
- Scans GPO state for GPO reports with a DACL entry inherited from the parent container (HasInheritedPermissions is true) and reports counts and a small sample.
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.

#### Related Tests
- `Test-MtAdGpoInheritedPermissionsCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
