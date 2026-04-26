#### Test-MtAdDisabledReplicationConnectionCount

#### Why This Test Matters

Disabled replication connections in Active Directory can indicate several security and operational concerns:

- **Replication Failures**: Disabled connections may indicate failed or problematic replication between domain controllers
- **Incomplete Decommissioning**: Disabled connections from decommissioned DCs that weren't properly cleaned up
- **Attack Indicators**: Malicious actors may disable replication to prevent detection of changes made to the directory
- **Operational Risk**: Inconsistent directory data across domain controllers can lead to authentication failures and access control issues

Replication connections should normally be enabled to ensure consistent directory data across all domain controllers.

#### Security Recommendation

- Regularly review disabled replication connections
- Investigate and resolve the root cause of disabled connections
- Remove connections for permanently decommissioned domain controllers
- Monitor for unexpected changes to replication connection status
- Document any intentionally disabled connections with business justification

#### How the Test Works

This test retrieves all Active Directory replication connections and counts:
- Total replication connections
- Disabled connections
- Enabled connections
- Percentage of disabled connections

#### Related Tests

- `Test-MtAdNonAutoReplicationConnectionCount` - Identifies manually created replication connections
