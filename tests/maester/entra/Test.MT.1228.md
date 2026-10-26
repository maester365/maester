RBAC for Applications in Exchange Online lets you grant an app a permission, such as `Mail.Read`, for a limited set of mailboxes.

Permissions granted in Exchange Online and in Microsoft Entra ID add together. If the app also holds the same Microsoft Graph application permission in Microsoft Entra ID, or a broader one that includes it (for example `Mail.ReadWrite` covers `Mail.Read`), that grant covers every mailbox in the organization, so the Exchange scope has no effect. The app can read or change mail far beyond what the Exchange assignment suggests.

This test fails when an app holds a permission through a scoped Exchange RBAC for Applications assignment and the same or a broader permission through a tenant-wide Microsoft Graph grant.

#### Remediation action

For each app listed below, keep the scoped Exchange assignment and remove the tenant-wide grant in Microsoft Entra ID.

1. In the Microsoft Entra admin center, open [Enterprise applications](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/StartboardApplicationsMenuBlade/~/AppAppsPreview) and select the app.
2. Open **Security** > **Permissions**.
3. Under **Admin consent**, find the Microsoft Graph permission shown in the **Entra grant** column of the result and select **Revoke permission**.
4. Confirm the app still works for the mailboxes in its Exchange scope. You can check the effective Exchange permissions with `Test-ServicePrincipalAuthorization -Identity <AppId>`.

#### Related links

* [Role Based Access Control for Applications in Exchange Online - Microsoft Learn](https://learn.microsoft.com/exchange/permissions-exo/application-rbac)
* [Review permissions granted to enterprise applications - Microsoft Learn](https://learn.microsoft.com/entra/identity/enterprise-apps/manage-application-permissions)

<!--- Results --->
%TestResult%
