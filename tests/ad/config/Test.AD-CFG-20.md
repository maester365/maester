Inventories CRL distribution point objects published in Active Directory.

Lists each object's name, distinguished name and whether a CRL attribute is present. This inventory does not decode the CRL, test its freshness, or test whether clients can reach a distribution point.

#### Control Type

**Operational**

#### Security Recommendation

Confirm published CDPs and their reachability with PKI owners using independent revocation-health checks. Do not infer CRL freshness from object presence.

#### How the Test Works

The test inventories CDP object names, distinguished names and CRL-attribute presence; it does not decode CRLs, assess expiry or test client access.

#### Related Tests

- **AD-CFG-15 — CA certificate inventory** — `Test-MtAdEnrollmentCaCertificateDetails` — Inventories associated public CA certificates.

#### Remediation action

Review unexpected CDP objects with the PKI owner. If revocation availability is in doubt, use the organization's CRL publication and client validation procedures rather than treating this inventory as a revocation health test.

#### Related links

* [Certificate revocation lists](https://learn.microsoft.com/windows-server/identity/ad-cs/certificate-revocation-lists)

<!--- Results --->
%TestResult%
