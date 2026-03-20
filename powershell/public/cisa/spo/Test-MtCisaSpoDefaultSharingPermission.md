File and folder default sharing permissions SHALL be set to view only.

Rationale: Setting the default link permissions to "View" limits sharing to view-only access for files and folders shared in SharePoint. This default reduces the risk of unintentional editing or modification of shared content by external parties or other users.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select **Policies** > **Sharing**.
3. Under **File and folder links**, set the default permission to **View**.
4. Select **Save**.

#### Related links

* [CISA 2 Default Sharing Settings - MS.SHAREPOINT.2.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint22v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%