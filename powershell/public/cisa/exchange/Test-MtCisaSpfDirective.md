An SPF policy SHALL be published for each domain, designating only these addresses as approved senders.

Rationale: An adversary may modify the `FROM` field of an email such that it appears to be a legitimate email sent by an agency, facilitating phishing attacks. Publishing an SPF policy for each agency domain mitigates forged `FROM` fields by providing a means for recipients to detect emails spoofed in this way. SPF is required for FCEB departments and agencies by Binding Operational Directive (BOD) 18-01, "Enhance Email and Web Security".

Coexistence domains related to Hybrid Configuration Wizard (HCW) are skipped.
Production use of coexistence domains is discouraged, and additional controls, such as transport rules, should be used to restrict their use.

#### Remediation action:

SPF is not configured through the Exchange admin center, but rather via DNS records hosted by the agency's domain. Thus, the exact steps needed to set up SPF varies from agency to agency. See [Add or edit an SPF TXT record to help prevent email spam (Outlook, Exchange Online) | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/admin/get-help-with-domains/create-dns-records-at-any-dns-hosting-provider?view=o365-worldwide#add-or-edit-an-spf-txt-record-to-help-prevent-email-spam-outlook-exchange-online) for more details.

To test your SPF configuration, consider using a web-based tool, such as those listed under [How can I validate SPF records for my domain? | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/admin/setup/domains-faq?view=o365-worldwide#how-can-i-validate-spf-records-for-my-domain). Additionally, SPF records can be requested using the PowerShell tool `Resolve-DnsName`. For example:

`Resolve-DnsName example.onmicrosoft.com txt`

If SPF is configured, you will see a response resembling `v=spf1 include:spf.protection.outlook.com -all` returned; though by necessity, the contents of the SPF policy may vary by agency. In this example, the SPF policy indicates the IP addresses listed by the policy for "spf.protection.outlook.com" are the only approved senders for "example.onmicrosoft.com." These IPs can be determined via an additional SPF lookup, this time for "spf.protection.outlook.com." Ensure the IP addresses listed as approved senders for your domain are those identified for MS.EXO.2.1v1. [See SPF TXT record syntax for Microsoft 365 | Microsoft Learn](https://learn.microsoft.com/en-us/microsoft-365/security/office-365-security/email-authentication-anti-spoofing?view=o365-worldwide#spf-txt-record-syntax-for-microsoft-365) for a more in-depth discussion of SPF record syntax.

#### Related links

* [Exchange admin center - Accepted domains](https://admin.exchange.microsoft.com/#/accepteddomains)
* [CISA 2 Sender Policy Framework - MS.EXO.2.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo22v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L75)

<!--- Results --->
%TestResult%