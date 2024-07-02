A DMARC policy SHALL be published for every second-level domain.

Rationale: Without a DMARC policy available for each domain, recipients may improperly handle SPF and DKIM failures, possibly enabling spoofed emails to reach end users' mailboxes. Publishing DMARC records at the second-level domain protects the second-level domains and all subdomains.

#### Remediation action:

DMARC is not configured through the Exchange admin center, but rather via DNS records hosted by the agency's domain. As such, implementation varies depending on how an agency manages its DNS records. See [Form the DMARC TXT record for your domain | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/email-authentication-dmarc-configure?view=o365-worldwide#step-4-form-the-dmarc-txt-record-for-your-domain) for Microsoft guidance.

A DMARC record published at the second-level domain will protect all subdomains. In other words, a DMARC record published for `example.com` will protect both `a.example.com` and `b.example.com`, but a separate record would need to be published for `c.example.gov`.

To test your DMARC configuration, consider using one of many publicly available web-based tools. Additionally, DMARC records can be requested using the PowerShell tool `Resolve-DnsName`. For example:

`Resolve-DnsName _dmarc.example.com txt`

If DMARC is configured, a response resembling `v=DMARC1; p=reject; pct=100; rua=mailto:reports@dmarc.cyber.dhs.gov, mailto:reports@example.com; ruf=mailto:reports@example.com` will be returned, though by necessity, the contents of the record will vary by agency. In this example, the policy indicates all emails failing the SPF/DKIM checks are to be rejected and aggregate reports sent to reports@dmarc.cyber.dhs.gov and reports@example.com. Failure reports will be sent to reports@example.com.

#### Related links

* [Exchange admin center - Accepted domains](https://admin.exchange.microsoft.com/#/accepteddomains)
* [CISA 4 Domain-Based Message Authentication, Reporting, and Conformance (DMARC) - MS.EXO.4.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo41v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L147)

<!--- Results --->
%TestResult%