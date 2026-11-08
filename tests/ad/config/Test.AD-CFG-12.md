Inventories Enterprise certification authorities in Active Directory, including each CA's DNS host and published template names.

Review the count and identities against your approved PKI inventory. A CA or template count alone does not establish whether issuance is secure.

#### Control Type

**Operational**

#### Security Recommendation

Maintain an approved CA inventory and review additions or publication changes with PKI administrators. Verify issuance permissions and certificate health separately; a count alone does not establish security.

#### How the Test Works

The test enumerates Enterprise CA objects with DNS hosts and published template names; it reports an inventory rather than comparing the count against a universal baseline.

#### Related Tests

- **AD-CFG-13 — Certificate template publication inventory** — `Test-MtAdCertificateTemplatesCount` — Cross-references published template names.
- **AD-CFG-15 — CA certificate inventory** — `Test-MtAdEnrollmentCaCertificateDetails` — Inventories public CA certificates.

#### Remediation action

Review unexpected CA entries and template publications in the Active Directory **Enrollment Services** container with your PKI owner before changing them. Do not remove a CA or template solely because of this inventory.

#### Related links

* [Certificate template concepts](https://learn.microsoft.com/windows-server/identity/ad-cs/certificate-template-concepts)

<!--- Results --->
%TestResult%
