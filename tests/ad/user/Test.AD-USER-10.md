Workstation logon restrictions are inventoried for investigation, not treated as a pass/fail baseline. Their absence alone does not prove exposure.

#### Control Type

**Detective**

#### Security Recommendation

Review workstation restrictions for privileged and sensitive accounts against their owners' requirements; do not treat missing restrictions as a universal failure.

#### How the Test Works

The test inventories user accounts with configured logon workstation restrictions. It does not test effective sign-in policy or establish that unrestricted accounts are insecure.

#### Related Tests

- **AD-USER-11 — AdminCount users should be reviewed** — `Test-MtAdUserAdminCountCount` — Helps prioritize protected identities for review.

#### Remediation action
1. Review listed user restrictions with account owners in [Active Directory administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).
2. Remove obsolete restrictions and document restrictions required for sensitive accounts.

<!--- Results --->
%TestResult%
