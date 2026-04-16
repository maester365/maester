Expiration days for Anyone links SHALL be set to 30 days or less.

Rationale: Anyone links that do not expire or have excessively long expiration periods pose a persistent risk of unauthorized access. Setting an expiration of 30 days or less ensures that shared content access is time-limited.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select Policies > Sharing.
3. Under Advanced settings for Anyone links, check **These links must expire within this many days** and set to **30** days or less.
4. Select Save.

#### Related links

* [CISA 3 Anyone Link Expiration - MS.SHAREPOINT.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint31v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%
