#### Test-MtAdEnterpriseCaCount

#### Why This Test Matters
Enterprise Certification Authorities (CAs) issue certificates for domain authentication and other PKI-dependent services. An unauthorized or newly introduced Enterprise CA can issue valid certificates that authenticate users/computers, enabling impersonation, man-in-the-middle attacks, and potential privilege escalation.

#### Security Recommendation
- Maintain an allowlist of approved Enterprise CAs and treat CA additions as high-risk change events.
- Ensure only designated PKI administrators can create/modify CA objects.
- Validate CA certificate chains and revocation configuration after any CA change.
- Monitor and alert on deviations in the number of Enterprise CAs.

#### How the Test Works
- Enumerates Enterprise CA objects in Active Directory (enrollment-capable CA configuration objects).
- Counts how many Enterprise CAs are configured.
- Compares the observed count against the environment baseline and flags unexpected values.

#### Related Tests
- [Test-MtAdEnrollmentCaCertificateDetails](./Test-MtAdEnrollmentCaCertificateDetails.md): Reviews CA certificate validity periods and integrity.
- [Test-MtAdCertificateTemplatesCount](./Test-MtAdCertificateTemplatesCount.md): Ensures template exposure isn’t expanded beyond approved policies.
- [Test-MtAdTrustedRootCaCount](./Test-MtAdTrustedRootCaCount.md): Verifies trusted PKI trust anchors.
