# Test-MtAdGroupAdminCount

## Why This Test Matters

The AdminCount attribute is a critical Active Directory security marker that indicates a group is considered "protected" by the system. Groups with AdminCount set receive special security protections that prevent delegation of administrative privileges through inheritance. This test helps identify:

- **Privileged groups**: Groups that are members of protected groups like Domain Admins, Enterprise Admins, or Schema Admins
- **Security inheritance issues**: Groups that may have broken inheritance due to AdminCount settings
- **Audit targets**: Groups requiring enhanced monitoring due to their administrative nature
- **Delegation challenges**: Groups that cannot receive permissions through normal inheritance

## Security Recommendation

- Review all groups with AdminCount set to ensure they still require elevated privileges
- Remove groups from protected groups if they no longer need administrative access
- Be aware that removing a group from a protected group does not automatically clear the AdminCount attribute
- Manually clear AdminCount for groups that should no longer be protected
- Monitor changes to AdminCount attributes as they indicate privilege escalation

## How the Test Works

This test retrieves all group objects from Active Directory and counts:
- Total number of groups
- Number of groups with AdminCount attribute set (non-null and greater than 0)
- Percentage of groups with AdminCount

## Related Tests

- `Test-MtAdGroupWithManagerCount` - Identifies groups with delegated management
- `Test-MtAdGroupSidHistoryCount` - Finds groups migrated from other domains
