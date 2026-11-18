Disabled ordinary users last modified over 180 days ago (configurable) require retention review. `Modified` is local `whenChanged`, **not** a disable date; other edits reset this estimate and it is not replicated. Protected/system accounts, RID 500–503, secondary krbtgt identities and Azure AD krbtgt accounts are excluded; this check does not delete RODC keys.

#### Control Type

**Detective**

#### Security Recommendation

Review disabled users against approved retention and legal holds; verify the disable date before removing accounts. Never use modification time as proof of when an account was disabled.

#### How the Test Works

The test checks disabled ordinary users whose `Modified` timestamp is older than `RetentionDays` (default 180), excluding protected/system accounts, RID 500–503 and krbtgt variants. `Modified` is a local, non-replicated change timestamp and only a proxy for retention age.

#### Related Tests

- **AD-USER-02 — Enabled users should not remain dormant** — `Test-MtAdUserDormantEnabledCount` — Reviews enabled users with old logon timestamps.
- **AD-USER-08 — Enabled users should not remain unused after provisioning** — `Test-MtAdUserNeverLoggedInCount` — Reviews users with no recorded logon.

#### Remediation action
1. Verify the actual disable date and legal retention requirements with the account owner.
2. After approval, remove stale objects in [Active Directory Users and Computers](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).

<!--- Results --->
%TestResult%
