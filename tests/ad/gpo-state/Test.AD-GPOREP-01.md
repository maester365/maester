Checks whether each evaluated GPO has permission entries in its collected permission
report. A readable GPO with no entries is a finding and fails this test. This is a
read-only assessment of a preventive ACL setting; it does not change permissions or
calculate effective access.

#### Control Type

**Detective**

#### Why This Test Matters

A GPO with no reported permission entries may not be manageable or accessible to its
intended policy recipients. An unintentionally empty DACL can prevent policy
retrieval and stop intended security settings from being applied.
The entry count alone does not identify every DACL state or determine effective
access. A NULL DACL grants full access and can expose the GPO to unauthorized
modification; an empty DACL denies access. Both can produce this entry-count
finding, so inspect the actual descriptor promptly to distinguish tampering
exposure from an availability problem.

#### Security Recommendation

Review GPOs reported with no permission entries and verify the intended delegation
and policy scope. Restore only permissions required by that design; do not infer
effective access from the entry count alone.

#### How the Test Works

- Reads the cached GPO permission reports and checks `PermissionsPresent`.
- A readable report with no entries is a finding; a report with entries satisfies
  this check, without establishing that the entries grant appropriate access.
- Unreadable permissions are unknown, not an empty list. If all reports are
  unknown, the test is skipped; partial unknowns with no findings result in
  **Investigate**. Any known finding still fails.
- Failed permission-report collection is an error. Details are shown for findings
  or unknown reports.
- Security-descriptor parsing currently requires Windows. On other platforms,
  these permissions are unknown and the test skips when no GPO can be evaluated.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO under **Delegation** >
   **Advanced** and review its actual security descriptor.
2. Confirm that authorized administrators and intended policy recipients retain
   the required access. Investigate unreadable descriptors before treating the
   inventory as complete.

#### Related Tests

- [AD-GPOREP-03 — GPOs should include Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-03) (`Test-MtAdGpoNoAuthenticatedUsersCount`) assesses a specific principal entry within the permission list checked here.
- [AD-GPOREP-06 — GPOs should include Domain Computers or Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-06) (`Test-MtAdGpoNoDomainComputersCount`) checks for either of two specified read-principal entries.
- [AD-GPOREP-10 — GPOs should have an Apply Group Policy allow entry](https://maester.dev/docs/tests/AD-GPOREP-10) (`Test-MtAdGpoNoApplyGroupPolicyAceCount`) checks for a specific application-right entry; none of these checks calculates effective access for every principal.
- [AD-GPOREP-07 — GPOs should not have deny access entries](https://maester.dev/docs/tests/AD-GPOREP-07) (`Test-MtAdGpoDenyAceCount`) reports deny entries.
- [AD-GPOREP-09 — GPOs should not inherit permission entries](https://maester.dev/docs/tests/AD-GPOREP-09) (`Test-MtAdGpoInheritedPermissionsCount`) reports inherited entries.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)
- [NULL and empty DACLs](https://learn.microsoft.com/windows/win32/secauthz/null-dacls-and-empty-dacls)

<!--- Results --->
%TestResult%
