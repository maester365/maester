Checks whether each evaluated GPO has an access-allowed permission entry for
**Domain Computers** or **Authenticated Users**. A known-present entry for either
satisfies this check; it fails only when both are known absent. This is a read-only
assessment of preventive ACL settings, not a calculation of effective read access.

#### Control Type

**Detective**

#### Why This Test Matters

Computer policy retrieval depends on suitable permissions. Incorrect read access
can prevent intended security settings from reaching computer accounts. However,
the absence of a
**Domain Computers** entry alone is not a failure: **Authenticated Users** may be
present instead. Conversely, entry presence does not establish that every intended
computer can effectively read the policy. Review the full ACL and intended scope.

#### Security Recommendation

Since MS16-072, Windows retrieves user-targeted Group Policy using the computer's
security context too. GPOs filtered to user groups therefore still need suitable
Read access for computer accounts, commonly through **Authenticated Users** or
**Domain Computers**. This does not mean granting those groups **Apply Group
Policy** or broadening which users receive the policy.

Confirm that each GPO's intended computer recipients have the required read access.
Do not add a principal solely to satisfy this check; account for the policy's
security filtering and the complete allow and deny entries.

#### How the Test Works

- Checks `HasDomainComputers` and `HasAuthenticatedUsers` in each cached permission
  report.
- Either known `true` value satisfies the check. Both known `false` values fail.
- If neither is known present and either value is unknown, that GPO is inconclusive.
  Unknown can mean an unreadable descriptor or conflicting allow and deny entries.
- If all GPOs are unknown, the test is skipped. Partial unknowns with no finding
  result in **Investigate**; known findings still fail. Failed collection is an
  error.

- Security-descriptor parsing currently requires Windows. On other platforms,
  these permissions are unknown and the test skips when no GPO can be evaluated.

#### Remediation action

Review each listed GPO's intended recipients and computer policy retrieval
requirements. Confirm the required read permissions for the relevant principals
before changing the ACL. A missing **Domain Computers** entry by itself is not a
finding; investigate unknown assessments by checking the descriptor and ACL.

#### Related Tests

- [AD-GPOREP-03 — GPOs should include Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-03) (`Test-MtAdGpoNoAuthenticatedUsersCount`) checks the **Authenticated Users** entry specifically.
- [AD-GPOREP-01 — No GPO should have an empty permissions list](https://maester.dev/docs/tests/AD-GPOREP-01) (`Test-MtAdGpoNoPermissionsCount`) checks for permission entries generally.
- [AD-GPOREP-10 — GPOs should have an Apply Group Policy allow entry](https://maester.dev/docs/tests/AD-GPOREP-10) (`Test-MtAdGpoNoApplyGroupPolicyAceCount`) checks for an explicit **Apply Group Policy** entry separately from these read-principal checks.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)
- [Group Policy security update background (MS16-072)](https://learn.microsoft.com/security-updates/securitybulletins/2016/ms16-072)
- [MS16-072: user-policy retrieval and required Read permissions (KB3163622)](https://support.microsoft.com/kb/3163622)

<!--- Results --->
%TestResult%
