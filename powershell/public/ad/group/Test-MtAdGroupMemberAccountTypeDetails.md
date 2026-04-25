# Test-MtAdGroupMemberAccountTypeDetails

## Why This Test Matters

A detailed breakdown of account types across group membership provides comprehensive visibility:

- **User Accounts**: Most common members - represent individual access
- **Group Nesting**: Groups within groups create hierarchical permissions
- **Computer Accounts**: Service accounts and system access requirements
- **Foreign Security Principals**: Cross-domain and cross-forest access

## Security Recommendation

Review account type distributions to identify:
- Over-reliance on group nesting that may create privilege escalation paths
- Unusual patterns (e.g., many computer accounts in privileged groups)
- External principals that may need periodic trust validation

## How the Test Works

This test provides a detailed analysis of group membership composition:
- Categorizes all unique members by their object class
- Shows count and percentage for each account type
- Identifies the distribution of member types across groups

For performance reasons, the test analyzes members from the first 50 groups and deduplicates by SID.

## Related Tests

- `Test-MtAdGroupMemberAccountTypeCount` - Count of distinct account types
- `Test-MtAdGroupMemberTrustDetails` - Detailed view of trust members by group
