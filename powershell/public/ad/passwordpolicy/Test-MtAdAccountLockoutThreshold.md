#### Test-MtAdAccountLockoutThreshold

#### Why This Test Matters

Account lockout threshold is one of the most important defenses against brute-force attacks:

* **Prevents automated attacks**: Limits the number of passwords an attacker can try
* **Detects attacks**: Lockout events can trigger alerts for security monitoring
* **Protects weak passwords**: Even users with weaker passwords get some protection

A threshold of 5 or fewer failed attempts provides strong protection while allowing for the occasional user mistake. Setting it to 0 (never lock out) removes this critical protection entirely.

#### Security Recommendation

Configure the account lockout threshold to **5 or fewer failed attempts**. Never disable account lockout (threshold = 0) as this removes critical protection against brute-force attacks.

To configure this setting:
1. Open **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Account Lockout Policy
4. Set **Account lockout threshold** to **5 or fewer invalid logon attempts**

**Note**: When you set the lockout threshold, Windows will suggest appropriate values for:
* Account lockout duration (recommend: 30 minutes)
* Reset account lockout counter after (recommend: 30 minutes)

#### How the Test Works

- Current lockout threshold (number of failed attempts)
- Recommended maximum (5 attempts)
- Critical warning if lockout is disabled

#### Related Tests

- `Test-MtAdAccountLockoutDuration` - Checks how long accounts remain locked
