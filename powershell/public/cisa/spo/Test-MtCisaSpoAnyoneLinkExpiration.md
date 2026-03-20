Expiration days for Anyone links SHALL be set to 30 days or less.

Rationale: Anyone links allow anonymous access to shared content. Setting an expiration of 30 days or less ensures that anonymous links do not persist indefinitely, reducing the window of exposure for unprotected content sharing.

This policy is only applicable if the external sharing slider on the admin page is set to Anyone.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Check **These links must expire within this many days** and set the value to **30** or less.
5. Select **Save**.

#### Related links

* [CISA 3 Anyone Links - MS.SHAREPOINT.3.1v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint31v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%