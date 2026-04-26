#### Test-MtAdUserAdminCountCount

#### Why This Test Matters

The `AdminCount` attribute is commonly set on protected and privileged accounts. These users often inherit AdminSDHolder protections and may retain elevated access or restricted ACL inheritance.

- **Privilege visibility**: Highlights accounts that may be administrative or formerly administrative
- **Delegation impact**: Protected accounts behave differently from standard users
- **Security review**: Helps identify users that warrant stronger monitoring and change control

#### Security Recommendation

- Review each account with `AdminCount = 1` to confirm it still requires elevated protections
- Validate that privileged accounts are intentionally assigned and documented
- Investigate stale or unexpected protected users and remove unnecessary privileged group membership

#### How the Test Works

This test counts user objects where the `AdminCount` attribute equals `1`.

#### Related Tests

- `Test-MtAdUserNonStandardPrimaryGroupCount` - Finds users with unusual group membership baselines
- `Test-MtAdUserSpnSetCount` - Identifies potentially high-value service accounts
