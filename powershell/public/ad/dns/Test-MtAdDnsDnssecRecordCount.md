#### Test-MtAdDnsDnssecRecordCount

#### Why This Test Matters

DNSSEC (DNS Security Extensions) provides authentication of DNS data through digital signatures. Trust anchors are the starting points for DNSSEC validation:

- **Data integrity**: DNSSEC prevents DNS spoofing and cache poisoning
- **Authentication**: Clients can verify DNS responses are authentic
- **Compliance**: Some regulations require DNSSEC deployment
- **Trust establishment**: Trust anchors enable validation chains

#### Security Recommendation

- Deploy DNSSEC for all externally-facing DNS zones
- Maintain secure trust anchor distribution
- Monitor for DNSSEC validation failures
- Keep DNSSEC keys properly managed and rotated

#### How the Test Works

This test counts DNSSEC trust anchor records configured in the TrustAnchors zone.

#### Related Tests

- None currently
