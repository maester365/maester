Inventories public CA certificates in Enterprise enrollment services, trusted root and intermediate CA containers.

Reports the number of objects in each role and lists each public certificate's role, subject, issuer, validity dates and thumbprint. A certificate published in more than one role is reported once per role. An expired certificate is an observation, not a failed validity or rotation policy; no private keys are retrieved.

#### Control Type

**Operational**

#### Security Recommendation

Review CA certificate identities and expiry against the approved PKI inventory and validate trust and revocation independently before changes.

#### How the Test Works

The test inventories public CA certificate subject, issuer, dates, thumbprint and publication role in enrollment, trusted-root and intermediate containers. It does not enforce an expiry baseline or retrieve private keys.

#### Related Tests

- **AD-CFG-12 — Enterprise CA inventory** — `Test-MtAdEnterpriseCaCount` — Inventories issuing CA objects.
- **AD-CFG-21 — NTAuth certificate inventory** — `Test-MtAdNtAuthCertificatesCount` — Inventories certificates trusted for domain authentication.

#### Remediation action

Compare certificate identities and dates to your approved PKI inventory. Investigate unexpected or expired entries with your PKI owner and follow the established CA renewal process before making directory changes.

#### Related links

* [Active Directory Certificate Services overview](https://learn.microsoft.com/windows-server/identity/ad-cs/active-directory-certificate-services-overview)

<!--- Results --->
%TestResult%
