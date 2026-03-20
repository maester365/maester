The allowable file and folder permissions for Anyone links SHALL be set to view only.

Rationale: Anyone links that grant edit permissions allow anonymous users to modify shared content. By restricting these links to view-only access, organizations prevent unauthorized modifications to files and folders accessed via anonymous links.

This policy is only applicable if the external sharing slider on the admin page is set to Anyone.

#### Remediation action:

1. Sign in to the [SharePoint admin center](https://go.microsoft.com/fwlink/?linkid=2185219).
2. Select **Policies** > **Sharing**.
3. Expand **More external sharing settings**.
4. Under **Anyone links**, ensure **File permissions** is set to **View**.
5. Under **Anyone links**, ensure **Folder permissions** is set to **View**.
6. Select **Save**.

#### Related links

* [CISA 3 Anyone Links - MS.SHAREPOINT.3.2v1](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/baselines/sharepoint.md#mssharepoint32v1)
* [CISA ScubaGear Rego Reference](https://github.com/cisagov/ScubaGear/blob/main/PowerShell/ScubaGear/Rego/SharepointConfig.rego)

<!--- Results --->
%TestResult%