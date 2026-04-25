# Test-MtAdGroupMemberForeignSidCount

## Why This Test Matters

Foreign SIDs represent security identifiers from domains other than the current domain:

- **SID History**: Migrated accounts may retain original SIDs for access continuity
- **Trust Relationships**: External domain SIDs indicate trust-based access
- **Cross-Forest Access**: Forest trusts may introduce SIDs from entirely different forests
- **Security Auditing**: Foreign SIDs should be tracked as they bypass some local security checks

## Security Recommendation

Monitor and audit foreign SIDs carefully:
- Review SID history from domain migrations for continued necessity
- Verify that trust relationships with external domains are still required
- Be cautious of foreign SIDs in highly privileged groups
- Document all foreign SID sources for compliance and security reviews

## How the Test Works

This test analyzes group membership for foreign SIDs by:
- Comparing member SIDs against the current domain SID
- Identifying SIDs that don't match the local domain pattern
- Grouping foreign SIDs by their domain of origin
- Counting unique foreign SID principals

For performance reasons, the test analyzes the first 50 groups.

## Related Tests

- `Test-MtAdGroupMemberTrustCount` - Count of trust members overall
- `Test-MtAdGroupMemberTrustDetails` - Detailed view by group
