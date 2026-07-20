#### Test-MtAdDnsRootServerIncorrectDetails

#### Why This Test Matters

Detailed information about incorrect root server configurations is essential for:

- **Rapid remediation**: Knowing exactly which servers are misconfigured enables quick fixes
- **Root cause analysis**: Understanding the scope helps identify how the misconfiguration occurred
- **Security incident response**: Unexpected changes may indicate compromise or attack
- **Compliance documentation**: Detailed records support audit requirements

#### Security Recommendation

When incorrect root server IPs are detected:
1. Document all discrepancies
2. Update root hints to match official IANA addresses
3. Investigate the cause of the discrepancy
4. Implement monitoring to detect future unauthorized changes

#### How the Test Works

This test provides detailed information about each root server that has an incorrect IP address, including:
- Configured IP address
- Expected (correct) IP address
- Status of all root servers

#### Related Tests

- `Test-MtAdDnsRootServerIncorrectCount` - Counts root servers with incorrect IPs
