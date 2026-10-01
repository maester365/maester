#### Test-MtAdFineGrainedPolicySettingCounts

#### Why This Test Matters

Having a detailed breakdown of fine-grained password policy settings allows you to:

- **Audit security levels**: Verify that privileged accounts have stronger policies
- **Identify misconfigurations**: Spot policies that may be incorrectly configured
- **Ensure compliance**: Validate that all policies meet minimum security requirements
- **Document coverage**: Understand exactly what controls are in place

This detailed view complements the value count by showing the actual settings rather than just the number of variations.

#### Security Recommendation

When reviewing fine-grained password policy settings, ensure:

| User Type | Min Length | Max Age | History | Complexity | Lockout Threshold |
|-----------|------------|---------|---------|------------|-------------------|
| Domain Admins | 15+ | 60 days | 24+ | Enabled | 3-5 |
| Service Accounts | 20+ | Never | 24+ | Enabled | 3-5 |
| Regular Users | 14+ | 90 days | 24 | Enabled | 5 |

To review and modify policy settings:
1. Open **Active Directory Administrative Center**
2. Navigate to **System** > **Password Settings Container**
3. Double-click each policy to review settings
4. Adjust as needed to meet security requirements

#### How the Test Works

This test retrieves all fine-grained password policies using `Get-ADFineGrainedPasswordPolicy` and creates a table showing key settings for each policy:
- Policy name
- Minimum password length
- Maximum password age (in days)
- Password history count
- Complexity enabled (Yes/No)
- Lockout threshold

#### Related Tests

- `Test-MtAdFineGrainedPolicyCount` - Counts the number of FGPPs
- `Test-MtAdFineGrainedPolicyValueCount` - Shows distinct values across policies
- `Test-MtAdFineGrainedPolicyAppliesTo` - Shows which users/groups each policy applies to
