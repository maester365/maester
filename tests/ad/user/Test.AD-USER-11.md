Accounts with `AdminCount=1` require human review; this flag can persist after privileged group removal and is not proof of current administrator rights.

#### Control Type

**Detective**

#### Security Recommendation

Review protected-user membership and ACL inheritance before clearing stale protection. `AdminCount` alone is not proof of current privilege.

#### How the Test Works

The test inventories users with `AdminCount=1` for human privilege review; the marker may persist after privileged group removal.

#### Related Tests

- **AD-USER-12 — Ordinary users should use an approved primary group** — `Test-MtAdUserNonStandardPrimaryGroupCount` — Reviews primary-group exceptions.
- **AD-SPN-12 — No domain admin accounts should have SPNs configured** — `Test-MtAdUserSpnDomainAdminCount` — Reviews SPNs on Domain Admins members.

#### Remediation action
1. Review group membership and inherited permissions in [AD administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Remove unnecessary privileges; clear stale protection only after validating the account is no longer protected.

<!--- Results --->
%TestResult%
