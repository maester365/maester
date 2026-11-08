Enabled ordinary users missing a manager can be omitted from manager-led identity reviews. Built-in and protected accounts are excluded; configure `ExcludedUsers` for documented exceptions.

#### Control Type

**Detective**

#### Security Recommendation

Keep manager records accurate for ordinary enabled identities when governance depends on manager-led reviews; document legitimate exceptions.

#### How the Test Works

The test checks the manager attribute on enabled ordinary users, excluding built-in/protected users and configured `ExcludedUsers`. It cannot establish whether a populated manager relationship is correct.

#### Related Tests

- **AD-USER-19 — Ordinary users should be managed in organizational units** — `Test-MtAdUserInContainerCount` — Reviews placement for delegated management.

#### Remediation action
1. Verify ownership and populate the manager attribute through [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Document account types for which no manager is appropriate.

<!--- Results --->
%TestResult%
