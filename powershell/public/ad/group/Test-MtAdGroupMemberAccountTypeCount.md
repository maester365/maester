# Test-MtAdGroupMemberAccountTypeCount

## Why This Test Matters

Understanding the types of objects that can be group members helps assess Active Directory security posture:

- **Security Principal Types**: Groups can contain users, groups, computers, and foreign security principals
- **Nested Groups**: Groups containing other groups create inheritance chains that can be complex to audit
- **Computer Membership**: Computers in groups may indicate service accounts or special access requirements
- **Foreign Principals**: External domain members represent trust relationships that extend beyond the local domain

## Security Recommendation

Monitor group membership composition:
- Nested group membership can create unexpected access paths
- Foreign security principals indicate cross-domain access that should be regularly reviewed
- Computer accounts in sensitive groups may indicate misconfigurations

## How the Test Works

This test analyzes group membership across Active Directory and:
- Identifies distinct object classes among group members
- Counts unique account types (user, group, computer, foreignSecurityPrincipal)
- Provides visibility into membership composition

For performance reasons, the test analyzes members from the first 50 groups and deduplicates by SID.

## Related Tests

- `Test-MtAdGroupMemberAccountTypeDetails` - Detailed breakdown of account types
- `Test-MtAdGroupMemberForeignSidCount` - Identifies foreign security principals specifically
