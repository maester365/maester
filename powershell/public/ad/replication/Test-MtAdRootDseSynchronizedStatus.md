#### Test-MtAdRootDseSynchronizedStatus

#### Why This Test Matters

The Root DSE (Directory Service Agent) synchronization status indicates whether a domain controller has completed its initial replication with replication partners:

- **Directory Consistency**: Unsynchronized DCs may have stale data
- **Authentication Reliability**: Users may experience authentication failures
- **Replication Health**: Indicates overall replication topology health
- **Operational Readiness**: New or recovered DCs need to complete sync before serving clients

A synchronized status (isSynchronized = TRUE) indicates the DC is ready to serve directory requests with current data.

#### Security Recommendation

- Monitor synchronization status after DC promotion or recovery
- Investigate DCs that remain unsynchronized for extended periods
- Ensure all DCs complete initial synchronization before production use
- Include synchronization status in regular health checks
- Alert on unexpected synchronization failures

#### How the Test Works

This test checks the Root DSE isSynchronized attribute and reports:
- Synchronization status (Yes/No)
- Server DNS name
- Domain, forest, and DC functionality levels

#### Related Tests

- `Test-MtAdDisabledReplicationConnectionCount` - Checks for disabled replication connections
- `Test-MtAdNonAutoReplicationConnectionCount` - Identifies manual replication connections
