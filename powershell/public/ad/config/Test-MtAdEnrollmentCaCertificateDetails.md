#### Test-MtAdEnrollmentCaCertificateDetails

#### Why This Test Matters
Enrollment-capable CA certificates include validity periods and other critical properties. Expired or invalid CA certificates can break certificate issuance and domain authentication flows. In addition, unexpected certificate replacements (e.g., unknown thumbprints) can indicate PKI tampering.

#### Security Recommendation
- Monitor CA certificate expiration and rotate certificates through an approved operational process.
- Validate certificate thumbprints/subjects/issuers against your known-good CA configuration.
- Alert when CA certificates are within your rotation window (commonly 30/60 days, depending on your policy).
- Ensure CRL/OCSP and publication settings remain correct after certificate updates.

#### How the Test Works
- Enumerates enrollment-capable CA objects in Active Directory.
- Retrieves CA certificate details associated with those enrollment services.
- Evaluates certificate validity (e.g., already expired, or expiring soon based on your configured thresholds) and highlights unexpected certificate identity details.

#### Related Tests
- [Test-MtAdEnterpriseCaCount](./Test-MtAdEnterpriseCaCount.md): Helps confirm which CAs are expected to exist.
- [Test-MtAdTrustedRootCaCount](./Test-MtAdTrustedRootCaCount.md): Validates the trust anchors that support issued certificates.
