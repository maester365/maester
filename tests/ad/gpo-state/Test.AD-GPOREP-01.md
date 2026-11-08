Checks for Group Policy objects whose security descriptor has no permission entries. An empty DACL needs investigation because it can disrupt policy management and application. Unreadable descriptors are listed separately and never treated as clean.

#### Why This Test Matters

An empty DACL denies access rather than widening it; it can prevent intended policy access and administration. An unreadable descriptor is a separate collection problem, not evidence that permissions are empty.

#### Control Type

**Preventive**

#### Security Recommendation

Review GPO delegation against the intended recipients and administrators; restore missing access rather than granting permissions indiscriminately.

#### How the Test Works

`Get-MtADGpoState` supplies the collected GPO reports. The check counts GPOs with `PermissionsPresent` false and reports unreadable permission sets as not evaluated; incomplete collection cannot yield a clean pass.

#### Related Tests

- **AD-GPOREP-10 — GPOs should have an Apply Group Policy allow entry** — `Test-MtAdGpoNoApplyGroupPolicyAceCount` — Reviews GPO application permissions.

#### Remediation action

1. In **Group Policy Management**, inspect the listed GPO's **Delegation** and **Advanced** security settings.
2. Restore the intended permissions and confirm that authorized administrators and policy recipients retain the required access. Investigate any GPO whose descriptor could not be read.

#### Related links

* [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
