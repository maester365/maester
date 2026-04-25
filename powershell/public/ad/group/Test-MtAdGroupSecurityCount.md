# Test-MtAdGroupSecurityCount

## Why This Test Matters

Security groups are the foundation of access control in Active Directory. Understanding their count and distribution is critical for:

- **Access management assessment**: High numbers of security groups may indicate complex or poorly managed permissions
- **Security auditing**: Security groups directly control who can access what resources
- **Privilege analysis**: Helps identify the scale of group-based access control to audit
- **Compliance requirements**: Many frameworks require documentation and regular review of security groups

Security groups can be assigned permissions to resources, unlike distribution groups.

## Security Recommendation

Establish governance around security groups:
1. Implement a naming convention for security groups to improve manageability
2. Regularly audit security group memberships, especially for privileged groups
3. Document the purpose and owner of each security group
4. Remove unused or stale security groups to reduce attack surface
5. Consider implementing privileged access management for highly sensitive groups

## How the Test Works

This test examines all group objects and identifies those where:
- The `GroupCategory` property equals "Security"
- These groups can be assigned permissions and used for access control

The test provides counts and percentages to understand the proportion of security groups versus distribution groups.

## Related Tests

- `Test-MtAdGroupDistributionCount` - Counts distribution groups (email-only)
- `Test-MtAdGroupDomainLocalCount` - Counts domain local scope groups
- `Test-MtAdGroupGlobalCount` - Counts global scope groups
- `Test-MtAdGroupUniversalCount` - Counts universal scope groups
