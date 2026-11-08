OUs with no selected visible direct children inventory.

Counts OUs with no directly visible user, group, computer or child OU. Other object classes are not queried; do not interpret the result as proof that an OU has no children. Replaces AD-OU-05.

An OU without the selected direct-child classes may be a placeholder or a candidate for review. It may still contain other directory objects, and a GPO link or delegated ACL can matter even if no selected children appear.

#### Control Type

**Detective**

#### Security Recommendation

1. Review the objects in **Active Directory Sites and Services** or **Active Directory Users and Computers**, as appropriate.
2. Review the reported objects with the directory and network owners; update any outdated configuration only after checking intended topology and dependencies.

Check all child classes, nested objects, policy links, delegated permissions and intended future use before considering cleanup. Keep intentionally reserved OUs documented and remove only those confirmed unnecessary.

#### How the Test Works

Checks visible direct user, group, computer and OU children for each OU, then reports OUs without any of those classes. It does not establish that an OU has no objects of any kind.

#### Related Tests

- **AD-OU-03 — OU modification age inventory** — `Test-MtAdOuStaleCount` — Inventories OU modification ages.
- **AD-GMC-08 — Empty non-privileged group count should be investigated** — `Test-MtAdGroupEmptyNonPrivilegedCount` — Reviews empty non-privileged groups separately.

#### Related links

* [Microsoft Learn: Reviewing OU Design Concepts](https://learn.microsoft.com/windows-server/identity/ad-ds/plan/reviewing-ou-design-concepts)

<!--- Results --->
%TestResult%
