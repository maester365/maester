#### Test-MtAdGroupWithManagerCount

#### Why This Test Matters

The ManagedBy attribute in Active Directory specifies who is responsible for managing a group. Assigning managers to groups provides several benefits:

- **Accountability**: Clear ownership for group membership decisions
- **Delegation**: Allows non-administrators to manage specific groups
- **Lifecycle management**: Facilitates regular review and cleanup
- **Audit trail**: Helps trace who authorized group changes
- **Self-service**: Enables business owners to manage their own access groups

However, not all groups need managers. Built-in groups, system groups, and highly privileged groups (like Domain Admins) should typically be managed only by IT administrators.

#### Security Recommendation

- Assign managers to business-purpose groups (department groups, project teams, etc.)
- Ensure managers understand their responsibilities for group membership review
- Implement a process for managers to regularly attest to group membership accuracy
- Do not assign managers to highly privileged groups that require IT-only management
- Consider using group expiration policies managed by group owners

#### How the Test Works

This test retrieves all group objects from Active Directory and:
- Checks the ManagedBy attribute for each group
- Counts groups where ManagedBy is populated (not null or empty)
- Calculates the percentage of managed vs. unmanaged groups

#### Related Tests

- `Test-MtAdGroupStaleCount` - Groups with managers should be reviewed regularly to prevent staleness
- `Test-MtAdGroupInContainerCount` - Groups with managers should typically be organized in appropriate OUs
