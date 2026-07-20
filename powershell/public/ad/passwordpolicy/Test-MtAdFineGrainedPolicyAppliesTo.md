#### Test-MtAdFineGrainedPolicyAppliesTo

#### Why This Test Matters

Understanding which users and groups each fine-grained password policy applies to is essential for:

- **Verifying coverage**: Ensure all privileged accounts are covered by stronger policies
- **Avoiding gaps**: Identify users who should have stricter policies but don't
- **Preventing conflicts**: Spot users who may be subject to multiple conflicting policies
- **Audit compliance**: Demonstrate that security controls are applied appropriately

A policy that doesn't apply to anyone is wasted configuration. A policy that applies to the wrong users can create security gaps or usability issues.

#### Security Recommendation

Ensure your fine-grained password policies are applied correctly:

- **Privileged groups**: Domain Admins, Enterprise Admins, Schema Admins should have the strongest policies
- **Service accounts**: Accounts used for services and applications need appropriate policies
- **No gaps**: All users with elevated privileges should be covered
- **No conflicts**: Users should not be subject to multiple FGPPs (the one with the lowest precedence wins)

To review and modify policy application:
1. Open **Active Directory Administrative Center**
2. Navigate to **System** > **Password Settings Container**
3. Double-click a policy
4. In the **Directly Applies To** section, review and modify the users and groups

**Note**: If a user is subject to multiple FGPPs, the one with the lowest precedence number wins. If precedence is equal, the policy with the most specific match wins.

#### How the Test Works

This test retrieves all fine-grained password policies using `Get-ADFineGrainedPasswordPolicy` and shows which users and groups each policy applies to. For each policy, the test reports:
- Policy name
- List of users and groups the policy applies to
- Object type (user, group, etc.)
- Warning if a policy has no application targets

#### Related Tests

- `Test-MtAdFineGrainedPolicyCount` - Counts the number of FGPPs
- `Test-MtAdFineGrainedPolicySettingCounts` - Shows detailed settings for each policy
