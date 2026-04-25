# Test-MtAdNonAutoReplicationConnectionCount

## Why This Test Matters

Non-auto-generated (manual) replication connections bypass the Knowledge Consistency Checker (KCC) automatic topology generation. While sometimes necessary for specific scenarios, manual connections require careful management:

- **Topology Bypass**: Manual connections don't benefit from automatic optimization and failover
- **Documentation Gap**: Manual connections may lack proper documentation of their business purpose
- **Operational Debt**: Accumulated manual connections from past troubleshooting may no longer be needed
- **Security Risk**: Undocumented connections may hide unauthorized replication paths

## Security Recommendation

- Prefer auto-generated connections for standard replication topology
- Document all manual connections with business justification
- Regularly audit manual connections to ensure they are still required
- Remove manual connections that are no longer needed
- Use manual connections only for specific scenarios like site bridging

## How the Test Works

This test retrieves all Active Directory replication connections and identifies:
- Auto-generated vs. manual connections
- Count and percentage of manual connections
- Total replication connection count

## Related Tests

- `Test-MtAdDisabledReplicationConnectionCount` - Identifies disabled replication connections
