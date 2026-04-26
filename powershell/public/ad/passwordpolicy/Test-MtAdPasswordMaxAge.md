#### Test-MtAdPasswordMaxAge

#### Why This Test Matters

Maximum password age is a critical security control that forces users to change their passwords periodically. This control is important because:

- **Limits exposure window**: If a password is compromised, the attacker has a limited time to use it before the password expires
- **Reduces hash value**: Old password hashes that may have been extracted from breaches become useless after password changes
- **Forces regular hygiene**: Users must create new passwords regularly, reducing the chance of long-term password reuse across services

While NIST guidelines have shifted toward longer password ages (or no expiration) when combined with other controls like MFA, many compliance frameworks still require regular password changes. The 90-day recommendation balances security with usability.

#### Security Recommendation

Configure the maximum password age to **90 days or less** (or 0 for never expire if using modern authentication with MFA). For environments without comprehensive MFA deployment, regular password changes remain important.

To configure this setting:
1. Open **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy
4. Set **Maximum password age** to **90 days or less**

#### How the Test Works

This test retrieves the default domain password policy using `Get-ADDefaultDomainPasswordPolicy` and extracts the `MaxPasswordAge` value. The test reports:

* Current maximum password age in days
* Recommended maximum (90 days)
* Whether the configuration meets security best practices

#### Related Tests

- `Test-MtAdPasswordHistoryCount` - Checks password history enforcement
- `Test-MtAdPasswordMinLength` - Checks minimum password length
- `Test-MtAdPasswordComplexityRequired` - Checks if password complexity is enforced
