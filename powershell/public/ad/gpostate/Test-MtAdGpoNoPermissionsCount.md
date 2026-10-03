#### Test-MtAdGpoNoPermissionsCount

 Counts Group Policy Objects (GPOs) with missing permissions.

#### Why This Test Matters
- Detective control: counts GPO reports with missing permissions which could expose resources to unintended access.

#### Control Type

**Preventive**

#### Security Recommendation
- Review and remediate missing permissions in GPO ACLs.

#### How the Test Works
- Fetches GPO state, filters for reports with PermissionsPresent false or null, and reports totals.

#### Related Tests
- `Test-MtAdGpoNoPermissionsDetails`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
