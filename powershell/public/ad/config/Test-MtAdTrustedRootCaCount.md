#### Test-MtAdTrustedRootCaCount

#### Why This Test Matters
Trusted root CAs act as the trust anchors for an entire PKI trust chain. If an attacker (or a misconfiguration) introduces an unauthorized trusted root CA, they may be able to construct certificates that validate through the trust chain, enabling broad compromise of authentication, TLS validation, and signed trust decisions.

#### Security Recommendation
- Maintain an allowlist of trusted root CAs and require strong change control for trust additions/removals.
- Restrict permissions on PKI trust anchor configuration to only PKI administrators.
- After any change, verify certificate thumbprints/subjects, revocation publication, and distribution behavior.
- Alert on unexpected changes in the number of trusted root CAs.

#### How the Test Works
- Enumerates trusted root CA entries published in Active Directory (trust anchor objects).
- Counts the number of trusted root CAs.
- Compares the observed count to an environment baseline and flags unexpected increases/decreases.

#### Related Tests
- [Test-MtAdEnrollmentCaCertificateDetails](./Test-MtAdEnrollmentCaCertificateDetails.md): Validates CA certificate validity and identity details.
- [Test-MtAdEnterpriseCaCount](./Test-MtAdEnterpriseCaCount.md): Confirms which CAs are configured for enrollment across the environment.
