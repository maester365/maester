Regular users are not allowed to create security groups.

Security groups grant access to resources and are used in Conditional Access, licensing and role assignment. If every user can create them, group sprawl grows, ownership becomes unclear, and a group that is later used in an access decision can be created or controlled by someone who should have no say in it.

With the setting off, only users with a suitable administrative role, or an approved self-service process, create groups.

#### Remediation action

1. Sign in to the [Microsoft Entra admin center](https://entra.microsoft.com).
2. Go to **Entra ID** > **Groups** > [**General**](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General).
3. Under **Security groups**, set **Users can create security groups in Azure portals, API or PowerShell** to **No**.
4. Select **Save**.

#### Related links

* [Microsoft Entra admin center - Group general settings](https://entra.microsoft.com/#view/Microsoft_AAD_IAM/GroupsManagementMenuBlade/~/General)
* [Configure group settings in Microsoft Entra ID](https://learn.microsoft.com/entra/fundamentals/how-to-manage-groups)
* [CIS Microsoft 365 Foundations Benchmark v7.0.0 - 5.1.3.1](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%
