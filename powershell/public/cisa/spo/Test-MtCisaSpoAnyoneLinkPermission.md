Allowable file and folder permissions for Anyone links SHALL be set to View only.

Rationale: Allowing edit permissions on Anyone links increases the risk of unauthorized modifications to shared content. Restricting to View only limits the potential impact of anonymous access.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select Policies > Sharing.
3. Under Advanced settings for Anyone links, set the file and folder permissions to **View**.
4. Select Save.

#### Related links

* [CISA 3 Anyone Link Permission - MS.SHAREPOINT.3.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint32v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%
