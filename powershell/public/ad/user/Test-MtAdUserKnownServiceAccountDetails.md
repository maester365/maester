#### Test-MtAdUserKnownServiceAccountDetails

#### Why This Test Matters

Service accounts often run business-critical workloads and commonly receive exceptions such as long-lived credentials, SPNs, or privileged access. Naming-pattern reviews help defenders quickly identify accounts that deserve deeper validation.

- **Exposure reduction**: Find accounts likely used by services before attackers do.
- **Privilege review**: Verify service accounts are not over-privileged.
- **Credential hygiene**: Check for non-expiring passwords and stale patterns.
- **Inventory accuracy**: Confirm naming standards are applied consistently.

#### Security Recommendation

- Maintain a defined naming standard for service accounts.
- Review matched accounts for owner, purpose, and required privileges.
- Prefer gMSAs where possible instead of traditional user-based service accounts.
- Investigate service-like names that lack documentation.

#### How the Test Works

This test reviews AD user objects and flags accounts whose `SamAccountName` or `Name` matches common service-account conventions such as `svc-`, `service-`, `app-`, `sql-`, or `admin-svc`.

#### Related Tests

- `Test-MtAdUserDelegationConfiguredCount`
- `Test-MtAdUserDelegationDetails`
