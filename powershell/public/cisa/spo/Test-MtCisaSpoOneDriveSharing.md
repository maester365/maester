External sharing for OneDrive SHALL be limited to Existing guests or Only People in your organization.

Rationale: Restricting OneDrive sharing reduces the risk of unauthorized data exposure from individual user storage. Allowing broad external sharing of OneDrive content increases the attack surface.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select Policies > Sharing.
3. Adjust external sharing slider for OneDrive to **Existing guests** or **Only people in your organization**.
4. Select Save.

#### Related links

* [CISA 1 OneDrive Sharing - MS.SHAREPOINT.1.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint12v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%
