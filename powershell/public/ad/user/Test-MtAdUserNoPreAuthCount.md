#### Test-MtAdUserNoPreAuthCount

#### Why This Test Matters

Accounts that do not require Kerberos pre-authentication are directly exposed to AS-REP roasting. Attackers can request offline-crackable material without first proving knowledge of the password.

#### Security Recommendation

Require pre-authentication for all accounts unless there is a justified exception. Review and remove legacy settings that disable this protection.

#### How the Test Works

This test retrieves Active Directory user data from `Get-MtADDomainState` and counts users where `DoesNotRequirePreAuth = $true` or the corresponding `userAccountControl` bit is set.

#### Related Tests

- `Test-MtAdUserDelegationAllowedCount`
- `Test-MtAdUserKerberosDesOnlyCount`
- `Test-MtAdUserPasswordNotRequiredCount`
