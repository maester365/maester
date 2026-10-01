#### Test-MtAdCertificateTemplatesCount

#### Why This Test Matters
Certificate templates define which certificate types can be issued and under what conditions. Overly permissive or unexpected templates can allow broader enrollment than intended, enabling privilege escalation through misconfigured enrollment permissions, risky EKUs, or unintended autoenrollment.

#### Security Recommendation
- Establish and document the set of approved certificate templates for each CA.
- Review template permissions (who can enroll, who can manage) and enrollment constraints at least quarterly.
- Remove templates that are unused, deprecated, or risky (e.g., excessive EKUs, weak key protection settings, misconfigured subject name rules).
- Alert on unexpected additions/removals or unusual counts of templates.

#### How the Test Works
- Queries Active Directory for configured certificate template objects.
- Counts the total number of certificate templates present.
- Compares the observed count to an expected baseline and flags unexpected deviations.

#### Related Tests
- [Test-MtAdEnrollmentTemplatesCount](./Test-MtAdEnrollmentTemplatesCount.md): Assesses which templates are actually available for enrollment.
- [Test-MtAdEnterpriseCaCount](./Test-MtAdEnterpriseCaCount.md): Links template exposure to the CAs that can issue them.
