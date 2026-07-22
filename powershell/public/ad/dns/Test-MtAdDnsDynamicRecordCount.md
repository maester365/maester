#### Test-MtAdDnsDynamicRecordCount

#### Why This Test Matters

Dynamic DNS allows clients to register and update their own DNS records. While convenient, excessive dynamic registration can indicate:

- **Security risks**: Unauthorized devices may register in DNS
- **Configuration issues**: Misconfigured clients may create excessive records
- **Stale data**: Dynamic records may not be cleaned up properly
- **Resource exhaustion**: Too many dynamic records can impact DNS performance

Understanding the ratio of dynamic to static records helps assess the security and hygiene of your DNS environment.

#### Security Recommendation

- Enable secure dynamic updates only (require authentication)
- Implement aging and scavenging to remove stale records
- Monitor for unusual patterns in dynamic registration
- Restrict dynamic updates to authorized systems only

#### How the Test Works

This test counts DNS records that have timestamps (dynamic) versus those without (static) and reports the ratio.

#### Related Tests

- `Test-MtAdDnsZoneRecordDetails` - Provides detailed record counts per zone
