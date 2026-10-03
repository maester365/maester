#### Control Type

**Operational**

#### Test-MtAdGpoInheritedPermissionsCount

 Counts GPO reports with inherited permissions.

#### Why This Test Matters
- Detective control: checks for inherited permissions in GPOs which may lead to broader access than intended.

#### Security Recommendation
- Review inherited permissions and consider removing inheritance where not needed.

#### How the Test Works
- Scans GPO state for HasInheritedPermissions true and reports counts and a small sample.

#### Related Tests
- `Test-MtAdGpoInheritedPermissionsCount`.

#### Related links
- [Microsoft Learn - Group Policy management](https://learn.microsoft.com/windows-server/group-policy/) 
- ANSSI checkpoint: https://www.anssi.gouv.fr/
