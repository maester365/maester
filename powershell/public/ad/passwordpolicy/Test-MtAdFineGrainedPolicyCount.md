#### Test-MtAdFineGrainedPolicyCount

#### Why This Test Matters

Fine-grained password policies (FGPP) provide critical flexibility for security-conscious organizations:

- **Privileged account protection**: Apply stricter password policies to administrators and service accounts
- **Risk-based policies**: Different policies for different risk levels (e.g., IT admins vs. regular users)
- **Compliance flexibility**: Meet varying compliance requirements for different user populations
- **Service account security**: Enforce stronger policies for accounts that cannot use MFA

Without FGPPs, all users in the domain are subject to the same password policy, which often results in either:
- Too weak a policy for privileged accounts, or
- Too restrictive a policy for regular users, leading to workarounds

#### Security Recommendation

Consider implementing fine-grained password policies for:
- **Domain Admins and privileged accounts**: Stronger requirements (longer passwords, shorter max age)
- **Service accounts**: Long, complex passwords that don't expire (since they can't easily be changed)
- **High-risk users**: Users with access to sensitive data

To create a fine-grained password policy:
1. Open **Active Directory Administrative Center**
2. Navigate to **System** > **Password Settings Container**
3. Right-click and select **New** > **Password Settings**
4. Configure policy settings and apply to appropriate users/groups

#### How the Test Works

This test retrieves all fine-grained password policies using `Get-ADFineGrainedPasswordPolicy` and counts them. The test reports:
- Number of FGPPs configured
- Whether FGPPs are being used for granular policy control

#### Related Tests

- `Test-MtAdFineGrainedPolicyAppliesTo` - Shows which users/groups each policy applies to
- `Test-MtAdPasswordHistoryCount` - Checks the default domain password history
