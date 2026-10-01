#### Test-MtAdFineGrainedPolicyValueCount

#### Why This Test Matters

Understanding the variation in fine-grained password policy settings helps you:

- **Identify inconsistencies**: Spot policies that may be too lenient or too strict
- **Validate policy design**: Ensure you have appropriate differentiation between user types
- **Find gaps**: Discover if certain security controls are missing from some policies
- **Audit compliance**: Verify that all policies meet minimum security requirements

Having multiple distinct values indicates you're using FGPPs to differentiate security requirements. Having identical values across all policies may indicate unnecessary duplication.

#### Security Recommendation

Review your fine-grained password policies to ensure:
- **Privileged accounts** have the strongest policies (longest passwords, shortest max age)
- **Service accounts** have appropriate policies (very long passwords, no expiration if needed)
- **Regular users** have balanced policies (secure but usable)
- **No policies are weaker** than the default domain policy

To review policy values:
1. Open **Active Directory Administrative Center**
2. Navigate to **System** > **Password Settings Container**
3. Review each policy's settings
4. Ensure policies are appropriately differentiated

#### How the Test Works

This test retrieves all fine-grained password policies using `Get-ADFineGrainedPasswordPolicy` and counts distinct values for key settings:
- Minimum password length
- Maximum password age
- Password history count
- Complexity enabled
- Lockout threshold

The test reports the variety of settings across all policies.

#### Related Tests

- `Test-MtAdFineGrainedPolicyCount` - Counts the number of FGPPs
- `Test-MtAdFineGrainedPolicyAppliesTo` - Shows which users/groups each policy applies to
