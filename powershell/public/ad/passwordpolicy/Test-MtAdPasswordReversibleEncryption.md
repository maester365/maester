#### Test-MtAdPasswordReversibleEncryption

#### Why This Test Matters

Reversible encryption for passwords is one of the most dangerous settings in Active Directory:

- **Complete password exposure**: Unlike one-way hashes, reversible encryption allows passwords to be decrypted by anyone with access to the encryption key
- **Domain compromise risk**: If an attacker gains access to the domain, they can extract all passwords stored with reversible encryption
- **No security benefit**: This setting exists only for legacy application compatibility and provides no security benefit

**This setting should never be enabled** in a production environment. If legacy applications require it, consider alternative authentication methods or application modernization.

#### Security Recommendation

**Disable reversible encryption immediately** unless you have a documented, approved exception for a specific legacy application.

To verify and configure this setting:
1. Open **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy
4. Ensure **Store passwords using reversible encryption** is **Disabled**

If you find this enabled:
- Document all affected user accounts
- Identify which applications require this setting
- Plan migration to modern authentication methods
- Disable the setting and reset all affected passwords

#### How the Test Works

This test retrieves the default domain password policy using `Get-ADDefaultDomainPasswordPolicy` and checks the `ReversibleEncryptionEnabled` property. The test reports:
- Whether reversible encryption is currently enabled or disabled
- Recommended setting (Disabled)
- Critical security warning if enabled

#### Related Tests

- `Test-MtAdPasswordComplexityRequired` - Checks password complexity requirements
- `Test-MtAdPasswordMinLength` - Checks minimum password length
