#### Test-MtAdAccountLockoutDuration

#### Why This Test Matters

Account lockout duration is a critical control for preventing brute-force attacks while maintaining usability:

- **Brute-force protection**: Lockouts prevent attackers from trying unlimited password combinations
- **Automatic recovery**: Users can regain access after the duration expires without administrative intervention
- **Balance point**: Too short provides little protection; too long impacts productivity

A lockout duration of at least 30 minutes provides adequate protection against automated attacks while minimizing help desk calls. Setting it to 0 (until administrator unlocks) provides maximum security but requires administrative overhead.

#### Security Recommendation

Configure the account lockout duration to at least **30 minutes** for automatic unlock, or set to **0** for manual unlock only (maximum security).

To configure this setting:
1. Open **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Account Lockout Policy
4. Set **Account lockout duration** to **30 minutes or more** (or 0 for manual unlock)

#### How the Test Works

This test retrieves the default domain password policy using `Get-ADDefaultDomainPasswordPolicy` and extracts the `LockoutDuration` value. The test reports:
- Current lockout duration in minutes (or "until administrator unlocks" if 0)
- Recommended minimum (30 minutes)
- Whether the configuration meets security best practices

#### Related Tests

- `Test-MtAdAccountLockoutThreshold` - Checks the number of failed attempts before lockout
