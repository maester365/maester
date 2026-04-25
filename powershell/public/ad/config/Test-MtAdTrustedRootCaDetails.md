# Test-MtAdTrustedRootCaDetails

## Why This Test Matters
Trusted Root Certification Authorities (CAs) define which certificate chains are trusted for AD-integrated scenarios. If an unauthorized or misconfigured trusted root certificate is present, attackers may be able to mint certificates that validate in your environment.

This test focuses on the *details* of trusted root CAs, including certificate validity, to help detect:
- Expired root certificates that can break trust and authentication flows
- Unexpected/unauthorized root certificates that broaden your trust boundaries

## Security Recommendation
- Verify each trusted root CA certificate matches your approved public key infrastructure (PKI) inventory.
- Remove (or revoke and clean up) any trusted root CA entries that are not explicitly authorized.
- Establish monitoring/alerting for certificates approaching expiration so you can renew before outages occur.
- If roots were added during maintenance, record change tickets and validate thumbprints/subjects.

## How the Test Works
The test enumerates trusted root CA certificates configured for AD (or in the module’s AD configuration view), extracts identifying attributes (e.g., subject/issuer and thumbprint) and certificate validity dates, and reports which trusted roots are present and whether they are within their expected validity window.

## Related Tests
- [Test-MtAdTrustedRootCaCount](./Test-MtAdTrustedRootCaCount.md)
