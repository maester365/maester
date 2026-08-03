#### Test-MtAdDnsAdSrvRecordDetails

#### Why This Test Matters

Detailed SRV record information is critical for:

- **Troubleshooting**: Understanding which servers provide which services
- **Security auditing**: Verifying only authorized servers are advertised
- **Capacity planning**: Understanding service distribution across DCs
- **Incident response**: Quickly identifying affected services

SRV records contain priority and weight values that control client behavior. Understanding these values helps ensure optimal and secure service location.

#### Security Recommendation

Review SRV record details regularly:
- Verify target hosts are authorized domain controllers
- Check priority and weight values are appropriate
- Monitor for unauthorized SRV record additions
- Ensure SRV records are protected from modification

#### How the Test Works

This test provides detailed information about each AD DS SRV record, including:
- Service and protocol
- Target host and port
- Priority and weight values

#### Related Tests

- `Test-MtAdDnsAdSrvRecordCount` - Counts AD DS SRV records
