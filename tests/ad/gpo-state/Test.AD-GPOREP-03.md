Checks whether each evaluated GPO has an access-allowed permission entry for
**Authenticated Users**. Its absence is a review finding, not proof that the GPO
is exposed or unusable. This read-only check assesses a preventive ACL setting; it
does not change permissions or calculate effective access.

#### Control Type

**Detective**

#### Why This Test Matters

The principal's access can be part of how a GPO is read and targeted, but some
policies intentionally use other groups for security filtering. Treating the
absence as universally unsafe could broaden policy scope or grant access contrary
to the design. Review the intended recipients and permissions together.

#### Security Recommendation

Verify the policy's security filtering and delegation before changing its ACL.
Grant read or application permissions only to the intended principals; do not add
**Authenticated Users** or **Apply Group Policy** solely to clear this finding.

#### How the Test Works

- Checks the cached permission report's `HasAuthenticatedUsers` value for each
  GPO.
- A known-present entry satisfies the check; known absence is a finding and fails.
- Unknown can indicate an unreadable descriptor or conflicting allow and deny
  entries. If all GPOs are unknown, the test is skipped; partial unknowns without
  findings result in **Investigate**. Known findings still fail.
- Failed permission-report collection is an error. Details are shown for findings
  or unknown reports.

- Security-descriptor parsing currently requires Windows. On other platforms,
  these permissions are unknown and the test skips when no GPO can be evaluated.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Scope** >
   **Security Filtering** and **Delegation** > **Advanced** settings.
2. Confirm intended recipients and their read and application permissions. Review
   both descriptor readability and the ACL when the principal assessment is
   unknown; do not assume every unknown is a collection-permission failure.

#### Related Tests

- `AD-GPOREP-01` checks whether permission entries are present.
- `AD-GPOREP-06` checks for either **Domain Computers** or **Authenticated Users**;
  `AD-GPOREP-10` checks for an explicit **Apply Group Policy** entry.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
