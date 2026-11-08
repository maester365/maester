Inventories public CA certificates in Enterprise enrollment services, trusted root and intermediate CA containers.

Reports the number of objects in each role and lists each public certificate's role, subject, issuer, validity dates and thumbprint. A certificate published in more than one role is reported once per role. An expired certificate is an observation, not a failed validity or rotation policy; no private keys are retrieved.

#### Remediation action

Compare certificate identities and dates to your approved PKI inventory. Investigate unexpected or expired entries with your PKI owner and follow the established CA renewal process before making directory changes.

#### Related links

* [Active Directory Certificate Services overview](https://learn.microsoft.com/windows-server/identity/ad-cs/active-directory-certificate-services-overview)

<!--- Results --->
%TestResult%
