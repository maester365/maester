#### Test-MtAdGroupStaleCount

#### Why This Test Matters

Groups that have not been modified for an extended period (in this case, before 2020) may represent:

- **Abandoned groups**: Created for projects or purposes that no longer exist
- **Orphaned permissions**: Groups with memberships that haven't been reviewed
- **Security blind spots**: Groups that could be repurposed by attackers
- **Directory clutter**: Unused objects that complicate administration
- **Compliance issues**: Undocumented groups that auditors may question

Stale groups pose particular risks because:
- They may contain members who should have been removed
- They might grant access to resources that should be restricted
- Their purpose may be forgotten, making them difficult to audit

#### Security Recommendation

- Establish a regular review process for groups that haven't been modified recently
- Document all groups and their purposes
- Consider implementing a group lifecycle policy with automatic expiration
- Remove groups that are no longer needed after confirming they're not referenced
- Update the modifyTimeStamp by reviewing group membership periodically

#### How the Test Works

This test retrieves all group objects from Active Directory and:
- Examines the modifyTimeStamp property of each group
- Counts groups where modifyTimeStamp is before January 1, 2020
- Calculates the percentage of stale groups in the environment

#### Related Tests

- `Test-MtAdGroupWithManagerCount` - Groups with managers are more likely to be actively maintained
- `Test-MtAdGroupSidHistoryCount` - Stale groups may be remnants of domain migrations
