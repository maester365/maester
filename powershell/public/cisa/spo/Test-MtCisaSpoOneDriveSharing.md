External sharing for OneDrive SHALL be limited to Existing guests or Only people in your organization.

Rationale: Sharing information outside the organization via OneDrive increases the risk of unauthorized access. By limiting OneDrive external sharing, administrators decrease the risk of access to information.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select **Policies** > **Sharing**.
3. Adjust the external sharing slider for **OneDrive** to **Existing guests** or **Only people in your organization**.
4. Select **Save**.

#### Related links

* [CISA 1 External Sharing - MS.SHAREPOINT.1.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint12v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%