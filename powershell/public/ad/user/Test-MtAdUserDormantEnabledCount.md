#### Test-MtAdUserDormantEnabledCount

#### Why This Test Matters

Enabled user accounts that have not logged on for more than 90 days are a common sign of weak identity hygiene. Forgotten but still-enabled accounts can retain access, group memberships, and password material that attackers may target.

#### Security Recommendation

Investigate dormant enabled accounts and disable or remove those that are no longer needed. For exceptions such as break-glass or low-use service accounts, apply stronger controls and document ownership.

#### How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState`, filters to enabled users, and counts accounts where `LastLogonDate` is older than 90 days. The output shows the number and percentage of dormant enabled users.

#### Related Tests

- `Test-MtAdUserDisabledCount`
- `Test-MtAdUserNeverLoggedInCount`
- `Test-MtAdUserPasswordNeverExpiresCount`
