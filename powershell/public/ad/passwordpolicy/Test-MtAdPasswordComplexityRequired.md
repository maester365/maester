#### Test-MtAdPasswordComplexityRequired

#### Why This Test Matters

Password complexity requirements are a fundamental security control that helps prevent weak passwords:

- **Prevents common passwords**: Complexity requirements block easily guessable passwords like "password123" or "companyname2024"
- **Increases entropy**: Character diversity increases the search space for brute-force attacks
- **Meets compliance requirements**: Most security frameworks require password complexity

Complexity alone is not sufficient—length is equally important. The best approach combines both: long passwords (14+ characters) with complexity requirements.

#### Security Recommendation

**Enable password complexity requirements** to ensure passwords contain characters from at least three of these categories:
- Uppercase letters (A-Z)
- Lowercase letters (a-z)
- Numbers (0-9)
- Special characters (!@#$%^&*, etc.)

To configure this setting:
1. Open **Group Policy Management**
2. Navigate to the Default Domain Policy
3. Edit: Computer Configuration > Policies > Windows Settings > Security Settings > Account Policies > Password Policy
4. Enable **Password must meet complexity requirements**

#### How the Test Works

This test retrieves the default domain password policy using `Get-ADDefaultDomainPasswordPolicy` and checks the `ComplexityEnabled` property. The test reports:
- Whether complexity is currently enabled or disabled
- Recommended setting (Enabled)
- Whether the configuration meets security best practices

#### Related Tests

- `Test-MtAdPasswordHistoryCount` - Checks password history enforcement
- `Test-MtAdPasswordMaxAge` - Checks maximum password age
- `Test-MtAdPasswordMinLength` - Checks minimum password length
