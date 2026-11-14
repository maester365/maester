Checks whether CA certificates in the forest's NTAuth store have a currently valid cryptographic path to a root certificate published in Active Directory.

NTAuth can contain Microsoft or third-party CA certificates. Its authentication authorization role is separate from root trust. This check uses the existing cached AD configuration snapshot: `NtAuthCertificates` supplies the starting certificates, `TrustedRootCAs` supplies the explicit trust anchors, and the intermediate, enterprise-CA and NTAuth collections supply possible issuers. It reuses the certificate parser introduced by the AD certificate inventory checks in PR #2734.

The platform chain engine validates signatures, validity dates and certificate constraints using custom root trust. The starting certificate must itself be a CA and must permit certificate signing when a key-usage extension is present. Duplicate certificates are assessed once by SHA-256 certificate identifier. A path containing a certificate absent from the collected inventory is not accepted, including intermediates supplied from the runner's local cache.

The check is **Info / Preview** because an incomplete published inventory is not proof that authentication fails or that an unauthorized CA is trusted. Unverifiable paths produce **Investigate**. Missing collections, uncollected certificate attributes or malformed certificates produce **Error**, rather than a partial successful assessment. An observed empty NTAuth store is **Skipped / NotApplicable**.

No certificate downloads, AIA requests or revocation requests are made. A missing issuer remains a visible gap even if an AIA URL might supply it. Root publication in AD does not prove that each domain controller has received or trusts that root. This check does not evaluate CRL/OCSP status, strong certificate mappings, effective enrollment permissions, template settings, the issuing CA's policy, private keys or PKINIT success. It does not establish that the published roots are organizationally approved. It supports the certificate-path portion of NIST SC-17; it does not assert full compliance.

#### Remediation action

1. Compare the reported NTAuth and root certificate thumbprints with the organization's approved PKI inventory. Coordinate trust changes with the PKI and Active Directory owners; do not add an unknown root merely to make a path verify.
2. For incomplete paths, obtain and independently verify the missing public issuer certificates. Use the organization's publication procedures to repair the AD intermediate/root inventory where appropriate. Root trust and NTAuth authorization must be approved separately.
3. For invalid signatures, validity dates or CA constraints, investigate the published certificate and its issuing hierarchy. Renew or remove obsolete entries through the approved PKI lifecycle, accounting for dependent authentication services.
4. Re-run the check, then validate the effective trust stores, replication, revocation access, certificate mappings and authentication on the actual domain controllers separately.

#### Related links

- [Publish third-party CA certificates to Enterprise NTAuth](https://learn.microsoft.com/troubleshoot/windows-server/certificates-and-public-key-infrastructure-pki/import-third-party-ca-to-enterprise-ntauth-store)
- [Smart card logon with third-party CAs](https://learn.microsoft.com/troubleshoot/windows-server/certificates-and-public-key-infrastructure-pki/enabling-smart-card-logon-third-party-certification-authorities)
- [.NET X509ChainPolicy](https://learn.microsoft.com/dotnet/api/system.security.cryptography.x509certificates.x509chainpolicy)
- [Custom root trust](https://learn.microsoft.com/dotnet/api/system.security.cryptography.x509certificates.x509chainpolicy.trustmode)
- [AD-CFG-21: NTAuth certificate inventory](https://maester.dev/docs/tests/AD-CFG-21)

<!--- Results --->
%TestResult%
