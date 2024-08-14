Microsoft Purview Audit (Premium) logging SHALL be enabled.

Rationale: Standard logging may not include relevant details necessary for visibility into user actions during an incident. Enabling Microsoft Purview Audit (Premium) captures additional event types not included with Standard. Furthermore, it is required for government agencies by OMB M-21-13 (referred to therein by its former name, Unified Audit Logs w/Advanced Features).

#### Remediation action:

To set up Microsoft Purview Audit (Premium), see [Set up Microsoft Purview Audit (Premium) | Microsoft Learn](https://learn.microsoft.com/en-us/purview/audit-premium-setup?view=o365-worldwide).

#### Related links

* [Purview portal - Audit search](https://purview.microsoft.com/audit/auditsearch)
* [CISA 17 Audit Logging - MS.EXO.17.2](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/exo.md#msexo172v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/EXOConfig.rego#L913)

<!--- Results --->
%TestResult%