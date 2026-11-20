Checks whether each evaluated GPO has an access-allowed permission entry for
**Enterprise Domain Controllers**. A readable GPO without that entry is a finding,
not by itself proof of incorrect effective access. This read-only assessment does
not alter the preventive ACL setting.

#### Control Type

**Detective**

#### Why This Test Matters

If intended domain controllers cannot retrieve a policy, their security settings
may be missing or inconsistent. This principal-presence check does not establish
that retrieval failed: the entry's absence is not necessarily wrong for every
policy. An unnecessary ACL change can
alter delegation or policy scope. Use the finding to review the policy's purpose
and intended recipients, not as an instruction to add the principal everywhere.

#### Security Recommendation

Confirm whether Enterprise Domain Controllers require this permission for the
policy's design. Restore an entry only when needed for intended access, and review
the full ACL rather than treating principal presence as effective-access analysis.

#### How the Test Works

- Checks `HasEnterpriseDomainControllers` in the cached permission report for each
  GPO.
- A known-present entry satisfies the check; known absence fails.
- Unknown can indicate an unreadable descriptor or conflicting allow and deny
  entries. If all reports are unknown, the test is skipped; partial unknowns with
  no finding result in **Investigate**. Known findings still fail.
- Failed permission-report collection is an error. Details are shown for findings
  or unknown reports.

- Security-descriptor parsing currently requires Windows. On other platforms,
  these permissions are unknown and the test skips when no GPO can be evaluated.

#### Remediation action

Review each listed policy's purpose, recipients, and the role of Enterprise Domain
Controllers in its intended scope. Restore the permission only if required by that
design. For unknown assessments, check both descriptor readability and the ACL
before deciding whether collection access is the cause.

#### Related Tests

- `AD-GPOREP-01` checks for permission entries generally.
- `AD-GPOREP-03` and `AD-GPOREP-06` assess other read-principal entries; they are
  separate checks and do not calculate effective access.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
