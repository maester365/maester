#### Test-MtAdDnsZoneDelegationCount

#### Why This Test Matters

DNS zone delegations transfer authority for a subdomain to different name servers. Monitoring delegations is important because:

- **Security boundaries**: Delegations may cross administrative or security boundaries
- **External dependencies**: Delegations may point to external/untrusted servers
- **Configuration complexity**: Each delegation adds management overhead
- **Potential hijacking**: Unauthorized delegations could redirect traffic

#### Security Recommendation

- Audit all zone delegations regularly
- Verify delegated servers are under your organization's control
- Document the purpose of each delegation
- Monitor for unauthorized delegation changes

#### How the Test Works

This test counts NS records that represent delegations (where the record name is not "@"), indicating authority delegation to another server.

#### Related Tests

- `Test-MtAdDnsZoneDelegationDetails` - Provides detailed delegation information
