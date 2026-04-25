# Test-MtAdGroupMemberTrustDetails

## Why This Test Matters

Understanding which specific groups contain trust members is critical for security management:

- **Privileged Access**: Trust members in privileged groups (Administrators, Domain Admins) represent significant risk
- **Access Path Analysis**: Knowing which groups contain external members helps trace access paths
- **Trust Management**: Groups with many trust members may indicate over-reliance on external access
- **Compliance**: Some compliance frameworks require documentation of cross-domain access

## Security Recommendation

Perform detailed review of groups containing trust members:
- Prioritize review of privileged groups with external members
- Document the source domain and purpose of each trust member
- Establish processes to periodically validate continued need for external access
- Consider creating domain-local groups specifically for external access to maintain clear boundaries

## How the Test Works

This test provides detailed analysis of trust membership:
- Identifies which groups contain trust members
- Lists trust members per group with their SIDs and types
- Shows the distribution of external access across groups

For performance reasons, the test analyzes the first 50 groups and limits display to 10 members per group.

## Related Tests

- `Test-MtAdGroupMemberTrustCount` - Overall count of trust members
- `Test-MtAdGroupMemberForeignSidCount` - Analysis of foreign SIDs
