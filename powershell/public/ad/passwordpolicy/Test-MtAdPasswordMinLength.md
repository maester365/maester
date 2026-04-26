#### Test-MtAdPasswordMinLength

#### Why This Test Matters

Minimum password length is one of the most effective controls against password-based attacks:

- **Brute-force resistance**: Each additional character exponentially increases the time required to brute-force a password
- **Dictionary attack protection**: Longer passwords are less likely to appear in common password dictionaries
- **Modern standard**: NIST and Microsoft now recommend longer passwords over complex character requirements

A minimum of 14 characters aligns with current NIST guidelines and provides significantly better security than the traditional 8-character minimum. Passphrases (multiple words strung together) are an excellent way to achieve length while maintaining memorability.

#### Security Recommendation

Configure the minimum password length to at least **14 characters** (NIST SP 800-63B recommendation). Consider:
- Using passphrases instead of complex passwords
- Combining length with complexity for maximum security
- Educating users on creating memorable long passwords

To configure this setting:
1. Open **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy
4. Set **Minimum password length** to **14 or more**

#### How the Test Works

This test retrieves the default domain password policy using `Get-ADDefaultDomainPasswordPolicy` and extracts the `MinPasswordLength` value. The test reports:
- Current minimum password length
- Recommended minimum (14 characters)
- Whether the configuration meets security best practices

#### Related Tests

- `Test-MtAdPasswordHistoryCount` - Checks password history enforcement
- `Test-MtAdPasswordMaxAge` - Checks maximum password age
- `Test-MtAdPasswordComplexityRequired` - Checks if password complexity is enforced
