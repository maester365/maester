An agency point of contact SHOULD be included for aggregate and failure reports.

Rationale: Email spoofing attempts are not inherently visible to domain owners. DMARC provides a mechanism to receive reports of spoofing attempts. Including an agency point of contact gives the agency insight into attempts to spoof their domains.

Maester reads the DMARC record that applies to each accepted domain: the domain's own `_dmarc` record or, when it has none, the record of its organizational domain (for example `contoso.co.uk` for `mail.contoso.co.uk`). A domain passes when its record has at least one aggregate report (`rua`) address other than `reports@dmarc.cyber.dhs.gov` and at least one failure report (`ruf`) address. Microsoft-managed domains (`*.onmicrosoft.com`) are skipped.

#### Remediation action:

See MS.EXO.4.1v1 Instructions for an overview of how to publish and check a DMARC record. Ensure the record published includes:

* A point of contact specific to your agency in the RUA field.
* reports@dmarc.cyber.dhs.gov as one of the emails in the RUA field.
* One or more agency-defined points of contact in the RUF field.

#### Related links

* [Exchange admin center - Accepted domains](https://admin.exchange.microsoft.com/#/accepteddomains)
* [CISA 4 Domain-Based Message Authentication, Reporting, and Conformance (DMARC) - MS.EXO.4.4v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo44v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L252)

<!--- Results --->
%TestResult%