#### Test-MtAdPasswordHistoryCount

#### Why This Test Matters

Password history is a critical security control that prevents users from reusing their recent passwords. Without adequate password history:

* **Password cycling**: Users can quickly cycle through passwords to return to their favorite (often compromised) password
* **Compromised credential reuse**: If a password is breached, users may inadvertently reintroduce it into the environment
* **Weak compliance**: Many compliance frameworks require password history to prevent password reuse

The recommended minimum of 24 remembered passwords ensures that users cannot reuse passwords within a reasonable timeframe, forcing them to create truly unique passwords.

#### Security Recommendation

Configure the password history count to at least **24** (Microsoft and CIS recommendation). This prevents users from reusing their last 24 passwords, significantly reducing the risk of password reuse attacks.

To configure this setting:
1. Open **Active Directory Domains and Trusts** or **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy
4. Set **Enforce password history** to **24 or more**

#### How the Test Works

This test retrieves the default domain password policy using `Get-ADDefaultDomainPasswordPolicy` and extracts the `PasswordHistoryCount` value. The test reports:

* Current password history count
* Recommended minimum (24)
* Whether the configuration meets security best practices

#### Related Tests

- `Test-MtAdPasswordMaxAge` - Checks maximum password age
- `Test-MtAdPasswordMinLength` - Checks minimum password length
- `Test-MtAdPasswordComplexityRequired` - Checks if password complexity is enforced
