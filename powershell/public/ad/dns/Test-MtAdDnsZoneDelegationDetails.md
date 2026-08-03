#### Test-MtAdDnsZoneDelegationDetails

#### Why This Test Matters

Detailed information about DNS delegations is essential for:

- **Security auditing**: Understanding what subdomains are delegated and to whom
- **Dependency mapping**: Knowing which external servers are trusted
- **Incident response**: Quickly identifying affected delegations during incidents
- **Compliance documentation**: Maintaining records of DNS infrastructure

#### Security Recommendation

Review delegation details regularly and:
- Verify all target name servers are authorized
- Remove delegations for decommissioned services
- Document the purpose and owner of each delegation
- Implement monitoring for delegation changes

#### How the Test Works

This test provides detailed information about each zone delegation, including:
- Parent zone name
- Delegated subdomain
- Target name server

#### Related Tests

- `Test-MtAdDnsZoneDelegationCount` - Counts zone delegations
