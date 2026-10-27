#### Test-MtAdGpoNoPermissionsCount

 Counts Group Policy Objects (GPOs) with missing permissions.

#### Why This Test Matters
- Detective control: counts GPO reports with missing permissions which could expose resources to unintended access.

#### Control Type

**Preventive**

#### Security Recommendation
- Review and remediate missing permissions in GPO ACLs.

#### How the Test Works
- Fetches GPO state, counts the GPO reports whose DACL has no entries (PermissionsPresent is false), and reports totals.
- A GPO whose permissions could not be read is reported as not evaluated instead of as a finding. The result is then Investigate, or Skipped when no GPO could be evaluated.

#### Related Tests
- `Test-MtAdGpoNoPermissionsDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/

<!--- Results --->
%TestResult%
