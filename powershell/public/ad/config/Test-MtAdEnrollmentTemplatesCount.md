# Test-MtAdEnrollmentTemplatesCount

## Why This Test Matters
Enrollment templates represent which certificate templates are available for users/computers to request through AD-integrated enrollment. If unnecessary or risky templates are available for enrollment, an attacker may enroll for certificates that enable authentication, code-signing abuse, or access to privileged resources.

## Security Recommendation
- Keep the enrollment template set minimal and aligned with your approved PKI strategy.
- Validate enrollment permissions and autoenrollment settings for each template that is enabled.
- Remove templates from enrollment that are not required for business operations.
- Monitor for unexpected changes to the number of enrollment templates.

## How the Test Works
- Identifies enrollment-capable configuration in AD and enumerates enrollment templates exposed via that configuration.
- Counts the number of available enrollment templates.
- Compares the count to an environment baseline and flags unexpected increases (new template exposure) or decreases (possible misconfiguration/incident).

## Related Tests
- [Test-MtAdCertificateTemplatesCount](./Test-MtAdCertificateTemplatesCount.md): Broader view of templates defined in AD.
- [Test-MtAdEnrollmentCaCertificateDetails](./Test-MtAdEnrollmentCaCertificateDetails.md): Ensures the CAs behind enrollment are healthy and not expired.
