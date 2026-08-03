#### Test-MtAdGroupSidHistoryCount

#### Why This Test Matters

- SID History is an attribute used during Active Directory domain migrations to maintain access to resources in the source domain:
- Groups with SID History are important to monitor because persistent SID History on groups can indicate:
- **Incomplete migrations**: Groups that were migrated but never fully transitioned
- **Security risks**: SIDs from untrusted or decommissioned domains may grant unintended access
- **Directory bloat**: Unnecessary data that complicates troubleshooting and auditing
- **Audit complexity**: Makes it difficult to determine effective permissions
- **Trust dependencies**: Hidden dependencies on domains that may no longer exist
- Groups with SID History are particularly concerning because they often control access to resources, and the SID History may grant access to users or groups from the source domain.

#### Security Recommendation

- Review all groups with SID History to determine if migration is complete
- Remove SID History attributes once group memberships are verified in the new domain
- Be cautious of SID History containing SIDs from external or untrusted domains
- Document any groups that legitimately require long-term SID History
- Regularly audit SID History contents during security reviews

#### How the Test Works

- This test retrieves all group objects from Active Directory and:
- Checks the SIDHistory attribute for each group
- Counts groups where SIDHistory is populated with one or more SIDs
- Calculates the percentage of groups with SID History

#### Related Tests

- `Test-MtAdGroupStaleCount` - Groups with SID History may also be stale if migration was long ago
- `Test-MtAdGroupAdminCount` - Privileged groups with SID History require special attention
