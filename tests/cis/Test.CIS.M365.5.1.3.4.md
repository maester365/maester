5.1.3.4 (L2) Ensure that 'Users can create Microsoft 365 groups in Azure portals, API or PowerShell' is set to 'No'

All users within a Microsoft Entra organization are permitted to create new Microsoft 365 groups and add members to those groups through the Azure portal, API, or PowerShell. Newly created groups also appear in the Access Panel for all other users. When the applicable group policy settings allow it, users can submit requests to join these groups.

The recommended state is **No**.

#### Rationale

Restricting Microsoft 365 group creation to administrators only ensures that creation of Microsoft 365 groups is controlled by the administrator. Appropriate groups should be created and managed by the administrator and group creation rights should not be delegated to any other user.

#### Impact

Enabling this setting could create a number of requests that would need to be managed by an administrator.

#### Remediation action

To remediate using the UI:

1. Navigate to [Microsoft Entra admin center](https://entra.microsoft.com).
2. Expand **Entra ID** > **Groups** and select [**General**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General).
3. Set **Users can create Microsoft 365 groups in Azure portals, API or PowerShell** to **No**.
4. Click **Save**.

To remediate using the Microsoft Graph API:

1. Execute a **PATCH** request to the following relative URI: `v1.0/groupSettings`
2. Target the object with the **templateId** of `62375ab9-6b52-47ed-826b-58e47e0e304b`.
3. Update **EnableGroupCreation** to **false**.

> **Note:** If a group with the above templateId doesn't exist this means the defaults are present and it would be advisable to use the UI to remediate, as this will automatically create the Group.Unified object with its defaults. Microsoft's documentation does cover using a POST request to build this using the API, however.

#### Related links

* [Microsoft Entra admin center - Group general settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General)
* [Manage who can create Microsoft 365 Groups](https://learn.microsoft.com/microsoft-365/solutions/manage-creation-of-groups)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.3.4](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
