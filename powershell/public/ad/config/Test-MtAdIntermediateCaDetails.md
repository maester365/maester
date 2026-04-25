# Test-MtAdIntermediateCaDetails

## Why This Test Matters
Intermediate CA certificates define the intermediate links used to build trust chains from trusted roots to issued certificates. If intermediate CA certificates expire, misconfigured, or unauthorized certificates are added, certificate chain validation can fail and authentication may break.

This test concentrates on *intermediate CA details* (including certificate validity) to help detect:
- Expired or soon-to-expire intermediate CAs that will break certificate chains
- Unexpected/unauthorized intermediates that expand who can issue certificates

## Security Recommendation
- Confirm each intermediate CA certificate is part of your approved PKI hierarchy.
- Remove unauthorized intermediates and ensure only valid chain-building intermediates are retained.
- Set renewal timelines and alerting for intermediates approaching expiration.
- If you rotate intermediates, validate that dependent relying parties and AD-integrated flows continue to validate.

## How the Test Works
The test enumerates intermediate CA certificates in the AD configuration context, extracts relevant identifiers (e.g., subject/issuer and thumbprint) and validity periods, and reports whether each intermediate is within the expected valid timeframe.

## Related Tests
- [Test-MtAdIntermediateCaCount](./Test-MtAdIntermediateCaCount.md)
