#### Test-MtAdDnsRootServerIncorrectCount

#### Why This Test Matters

Root DNS server hints are essential for external DNS resolution. Incorrect root server IP addresses can:

- **Prevent external DNS resolution**: Clients cannot resolve internet domain names
- **Indicate compromise**: Unexpected changes may indicate DNS poisoning attacks
- **Cause service outages**: Applications dependent on external DNS will fail
- **Impact security updates**: Systems may be unable to reach update servers

The root server IP addresses are maintained by IANA and change very infrequently. Any deviation from the official addresses should be investigated immediately.

#### Security Recommendation

- Verify root server hints against the official IANA list
- Investigate any discrepancies immediately
- Use secure update mechanisms for root hints
- Monitor for unauthorized changes to DNS configuration

#### How the Test Works

This test compares configured root server IP addresses against the official IANA root server list and reports any discrepancies.

#### Related Tests

- `Test-MtAdDnsRootServerIncorrectDetails` - Provides detailed information about incorrect root servers
