An SPF policy SHALL be published for each accepted domain that fails all non-approved senders.

Rationale: An adversary may modify the `FROM` field of an email such that it appears to be a legitimate email sent by an agency, facilitating phishing attacks. Publishing an SPF policy for each agency domain mitigates forged `FROM` fields by providing a means for recipients to detect emails spoofed in this way. SPF is required for FCEB departments and agencies by Binding Operational Directive (BOD) 18-01, "Enhance Email and Web Security". SCuBA accepts either a hard fail (`-all`) or soft fail (`~all`) mechanism; a redirect modifier is also accepted as in ScubaGear.

This check evaluates every accepted domain, including coexistence domains, to match the SCuBA evaluation scope.

If no accepted domains are returned, the check fails because the audited domains cannot be assessed. Verify that Exchange Online accepted domains can be retrieved, then rerun the check.

Every accepted domain is checked. A domain that sends email must name Exchange Online as an approved sender. A parked domain, one that never sends email, has no approved senders, so it only needs a policy that fails all senders, such as `v=spf1 -all` (`~all` is also accepted, as in MS.EXO.2.2v3).

Maester does not guess which domains are parked, and turning off **Allow mail to be sent from this domain** in Exchange no longer leaves a domain out of this test. List your parked domains in the `ParkedDomains` global setting, or in this test's `ParkedDomains` parameter:

```json
{
  "GlobalSettings": { "ParkedDomains": ["contoso-old.com"] }
}
```

#### Remediation action

SPF is not configured through the Exchange admin center, but rather via DNS records hosted by the agency's domain. Thus, the exact steps needed to set up SPF varies from agency to agency. See [Add or edit an SPF TXT record to help prevent email spam (Outlook, Exchange Online) | Microsoft Learn](https://learn.microsoft.com/microsoft-365/admin/get-help-with-domains/create-dns-records-at-any-dns-hosting-provider?view=o365-worldwide#add-or-edit-an-spf-txt-record-to-help-prevent-email-spam-outlook-exchange-online) for more details.

To test your SPF configuration, consider using a web-based tool, such as those listed under [How can I validate SPF records for my domain? | Microsoft Learn](https://learn.microsoft.com/microsoft-365/admin/setup/domains-faq?view=o365-worldwide#how-can-i-validate-spf-records-for-my-domain). Additionally, SPF records can be requested using the PowerShell tool `Resolve-DnsName`. For example:

`Resolve-DnsName example.onmicrosoft.com txt`

If SPF is configured, you will see a response resembling `v=spf1 include:spf.protection.outlook.com -all`; the contents of the policy may vary by agency. This check applies the SCuBA heuristic to each accepted domain: the parsed SPF record must contain a `-all` or `~all` mechanism, or a redirect modifier. A passing result is not proof that the redirect target rejects all non-approved senders, and the check does not validate individual sender addresses; review the reported records. See [SPF TXT record syntax for Microsoft 365 | Microsoft Learn](https://learn.microsoft.com/microsoft-365/security/office-365-security/email-authentication-anti-spoofing?view=o365-worldwide#spf-txt-record-syntax-for-microsoft-365) for more information.

#### Related links

* [Exchange admin center - Accepted domains](https://admin.exchange.microsoft.com/#/accepteddomains)
* [CISA 2 Sender Policy Framework - MS.EXO.2.2v3](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo22v3)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L145)

<!--- Results --->
%TestResult%
