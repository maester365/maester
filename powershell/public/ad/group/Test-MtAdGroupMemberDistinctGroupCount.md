# Test-MtAdGroupMemberDistinctGroupCount

## Why This Test Matters

Understanding which groups have members versus empty groups provides valuable insights into Active Directory utilization:

- **Group Hygiene**: Empty groups may represent unused or forgotten groups that could be cleaned up
- **Access Management**: Groups with members are actively used for access control and permissions
- **Audit Scope**: Focus security reviews on groups that actually grant access to resources
- **Directory Cleanup**: Identify candidates for decommissioning or consolidation

## Security Recommendation

Regularly review group membership to identify:
- Empty groups that can be removed or disabled
- Groups with unexpectedly few members (potential misconfigurations)
- Groups with excessive members (may need splitting for better access control)

## How the Test Works

This test analyzes Active Directory groups and counts:
- Total number of groups in the directory
- Number of groups that contain at least one member
- Percentage of groups with members
- Empty groups (for cleanup candidates)

For performance reasons, the test analyzes the first 100 groups if there are many groups in the directory.

## Related Tests

- `Test-MtAdGroupMemberAccountTypeDetails` - Breaks down member types across groups
- `Test-MtAdGroupMemberTrustCount` - Identifies cross-domain trust members
