Checks GPO security descriptors for inherited permission entries. Any evaluated GPO
with an inherited entry is a finding and fails this test. This is a read-only
assessment of a preventive ACL setting; it does not judge effective access or
change inheritance.

#### Control Type

**Detective**

#### Why This Test Matters

Inherited entries can carry permissions from a parent container into GPO
delegation. If a parent grants overly broad edit or permission-management rights,
those rights can enable unauthorized policy changes across its descendant GPOs.
Inherited permissions may be intended, but can also differ from the policy's expected
administrative scope. An inherited entry is therefore a review signal, not proof
of excessive access or a reason to disable inheritance automatically.

#### Security Recommendation

Review inherited entries and their source containers against the intended GPO
delegation. Preserve inheritance where it is part of the design; change it only
when the resulting ACL and policy administration remain appropriate.

#### How the Test Works

- Checks `HasInheritedPermissions` in each cached GPO permission report.
- A known inherited entry is a finding. This property describes entries in the
  descriptor; it does not indicate whether the descriptor was readable.
- Unreadable descriptors are unknown. If all are unknown, the test is skipped;
  partial unknowns without findings result in **Investigate**. Findings still
  fail when other reports are unknown.
- Failed permission-report collection is an error. Details are shown for findings
  or unknown reports.

- Security-descriptor parsing currently requires Windows. On other platforms,
  these permissions are unknown and the test skips when no GPO can be evaluated.

#### Remediation action

Review each listed inherited entry and identify its source container. Confirm that
the inherited access matches intended GPO delegation before changing permissions
or inheritance. Do not treat inheritance itself as a retrieval failure, and
investigate descriptors that could not be read.

#### Related Tests

- `AD-GPOREP-01` checks for permission entries generally.
- `AD-GPOREP-07` reports deny entries that may affect access alongside inherited
  entries.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
