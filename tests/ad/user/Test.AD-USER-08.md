Enabled accounts older than the configurable 30-day provisioning grace period with no recorded logon need review. A missing replicated timestamp is not definitive proof the user has never logged in.

#### Control Type

**Detective**

#### Security Recommendation

Investigate enabled accounts without recorded logons after their provisioning grace period and confirm use with domain-controller events before removing access.

#### How the Test Works

The test checks enabled users older than `ProvisioningGraceDays` (default 30) without a recorded replicated logon timestamp. No timestamp is not proof that a user has never logged on.

#### Related Tests

- **AD-USER-02 — Enabled users should not remain dormant** — `Test-MtAdUserDormantEnabledCount` — Reviews old recorded logons.
- **AD-USER-01 — Disabled users should be removed after the retention period** — `Test-MtAdUserDisabledCount` — Reviews disabled account retention.

#### Remediation action
1. Check authoritative authentication logs and ask the owner whether provisioning is complete.
2. Disable unnecessary accounts in [Active Directory administration](https://learn.microsoft.com/windows-server/identity/ad-ds/get-started/adac/active-directory-administrative-center).

<!--- Results --->
%TestResult%
