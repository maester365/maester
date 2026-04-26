#### Test-MtAdDfsrSubscriptionCount

#### Why This Test Matters

DFS-R (Distributed File System Replication) is the modern, recommended technology for replicating SYSVOL content between domain controllers:

- **Reliability**: DFS-R is more reliable than the legacy FRS (File Replication Service)
- **Scalability**: Better handles large SYSVOL contents and many DCs
- **Conflict Resolution**: Superior handling of file conflicts
- **Migration Status**: Indicates whether the domain has migrated from FRS to DFS-R

Microsoft recommends migrating from FRS to DFS-R for all domains. A count of DFS-R subscriptions compared to DC count shows migration coverage.

#### Security Recommendation

- Migrate all domains from FRS to DFS-R if not already done
- Ensure all domain controllers have DFS-R subscriptions
- Monitor DFS-R replication health regularly
- Document any DCs without DFS-R subscriptions
- Plan migration for any remaining FRS-based SYSVOL replication

#### How the Test Works

This test counts DFS-R subscription objects and reports:
- Total DFS-R subscription count
- Domain controller count
- Coverage percentage (subscriptions vs. DCs)
- Details of subscription objects

#### Related Tests

- `Test-MtAdDisabledReplicationConnectionCount` - Checks AD replication connection health
