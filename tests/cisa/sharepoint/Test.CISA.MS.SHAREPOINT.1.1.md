External sharing for SharePoint SHALL be limited to Existing guests or Only People in your organization.

Rationale: Sharing information outside the organization via SharePoint increases the risk of unauthorized access. By limiting external sharing, administrators decrease the risk of access to information.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select Policies > Sharing.
3. Adjust external sharing slider for SharePoint to Existing guests or Only people in your organization.

> ⚠️ WARNING: This will break existing sharing.

4. Select Save.

#### Related links

* [CISA 1 External Sharing - MS.SHAREPOINT.1.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint11v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego#L68)

<!--- Results --->
%TestResult%