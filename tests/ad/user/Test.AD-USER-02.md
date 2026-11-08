Enabled users with a recorded logon older than the configurable 90-day threshold are dormant. Replicated `lastLogonTimestamp` can lag by approximately 14 days; missing timestamps need separate review.

#### Control Type

**Detective**

#### Security Recommendation

Investigate dormant enabled accounts with their owners before disabling them; document exceptions for emergency and low-use accounts.

#### How the Test Works

The test compares the recorded replicated logon timestamp for enabled users with `DormantThresholdDays` (default 90). Replication lag and absent timestamps prevent this result from proving the exact last logon.

#### Related Tests

- **AD-USER-01 — Disabled users should be removed after the retention period** — `Test-MtAdUserDisabledCount` — Reviews retained disabled accounts.
- **AD-USER-08 — Enabled users should not remain unused after provisioning** — `Test-MtAdUserNeverLoggedInCount` — Reviews accounts without recorded logons.

#### Remediation action
1. Confirm actual use against domain-controller logon records before changing an account.
2. Disable unused identities through [Active Directory administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center) after owner approval.

<!--- Results --->
%TestResult%
