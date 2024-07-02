A list of approved IP addresses for sending mail SHALL be maintained.

Rationale: Failing to maintain an accurate list of authorized IP addresses may result in spoofed email messages or failure to deliver legitimate messages when SPF is enabled. Maintaining such a list helps ensure that unauthorized servers sending spoofed messages can be detected, and permits message delivery from legitimate senders.

#### Remediation action:

* Identify any approved senders specific to your agency.
* Perform regular review of SPF record and update as necessary.
* Additionally, see [External DNS records required for SPF](https://learn.microsoft.com/en-us/microsoft-365/enterprise/external-domain-name-system-records?view=o365-worldwide#external-dns-records-required-for-spf) for inclusions required for Microsoft to send email on behalf of your domain.

#### Related links

* [Exchange admin center - Accepted domains](https://admin.exchange.microsoft.com/#/accepteddomains)
* [CISA 2 Sender Policy Framework - MS.EXO.2.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo21v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L58)

<!--- Results --->
%TestResult%