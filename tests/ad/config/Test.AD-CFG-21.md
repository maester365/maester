Inventories public CA certificates published in the Active Directory NTAuth container.

Reports object and certificate counts, subject, issuer, validity dates and thumbprint. An expired certificate is listed for investigation; this inventory does not assert domain authentication or smart card login is working.

#### Remediation action

Compare the NTAuth certificates to the CAs approved for domain authentication. Review unexpected or expired entries with the PKI owner before changing the NTAuth store.

#### Related links

* [Import a third-party CA into the NTAuth store](https://learn.microsoft.com/troubleshoot/windows-server/certificates-and-public-key-infrastructure-pki/import-third-party-ca-to-ntauth-store)

<!--- Results --->
%TestResult%
