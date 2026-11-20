Checks whether every collected GPO has an explicit allow entry for **Apply Group
Policy**. A missing entry is a finding; generic administrative rights do not count
as an explicit application entry. This read-only check assesses a preventive ACL
setting and does not calculate effective permissions for each user or computer.

Here, "explicit" means a specific **Apply Group Policy** right rather than generic
rights. The check also accepts an inherited entry when it applies to the GPO itself;
it excludes inherit-only entries. It does not require that every qualifying ACE
was added directly to the GPO.

#### Control Type

**Detective**

#### Why This Test Matters

An explicit application entry is one part of how policy scope is represented in
the ACL. If intended recipients lack application rights, required security
settings may not be delivered to them. The entry's absence may indicate that the GPO is not configured for intended
recipients, but does not alone establish effective policy application. An unused
policy or an intentionally different design may also lack the entry.

#### Security Recommendation

Review the intended security filtering and application scope for each finding.
Grant **Apply Group Policy** only to principals that should receive the policy;
do not add a broad grant or a generic administrative entry to satisfy the check.

#### How the Test Works

- Requires Windows for security-descriptor parsing and checks
  `HasApplyGroupPolicyAce` in each collected report.
- A missing explicit allow entry fails. Generic administrative grants do not
  satisfy this specific check, and the result is not an effective-access
  calculation.
- An empty report set, unreadable permissions, or incomplete collection is an
  error, not a clean result. Findings are listed by GPO.

#### Remediation action

1. In **Group Policy Management**, inspect each listed GPO's **Scope** >
   **Security Filtering** and **Delegation** > **Advanced** settings.
2. Add an explicit **Apply Group Policy** grant only for intended recipients. If
   the GPO is intentionally unused, document that decision and consider its
   disposition rather than granting access solely to clear the finding.

#### Related Tests

- [AD-GPOREP-03 — GPOs should include Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-03) (`Test-MtAdGpoNoAuthenticatedUsersCount`) assesses a selected read-principal entry; this test checks the application entry separately.
- [AD-GPOREP-06 — GPOs should include Domain Computers or Authenticated Users permissions](https://maester.dev/docs/tests/AD-GPOREP-06) (`Test-MtAdGpoNoDomainComputersCount`) assesses selected read-principal entries; this test checks the explicit application entry separately.
- [AD-GPOL-01 — GPOs with enabled links should be investigated](https://maester.dev/docs/tests/AD-GPOL-01) (`Test-MtAdGpoLinkedCount`) inventories enabled links; a link alone does not establish that a policy applies to every target.

#### Related links

- [Group Policy overview](https://learn.microsoft.com/windows-server/identity/ad-ds/manage/group-policy/group-policy-overview)

<!--- Results --->
%TestResult%
