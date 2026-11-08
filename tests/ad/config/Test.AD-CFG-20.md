Inventories CRL distribution point objects published in Active Directory.

Lists each object's name, distinguished name and whether a CRL attribute is present. This inventory does not decode the CRL, test its freshness, or test whether clients can reach a distribution point.

#### Remediation action

Review unexpected CDP objects with the PKI owner. If revocation availability is in doubt, use the organization's CRL publication and client validation procedures rather than treating this inventory as a revocation health test.

#### Related links

* [Certificate revocation lists](https://learn.microsoft.com/windows-server/identity/ad-cs/certificate-revocation-lists)

<!--- Results --->
%TestResult%
