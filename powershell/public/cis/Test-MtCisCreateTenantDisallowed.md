5.1.2.3 (L1) Ensure 'Restrict non-admin users from creating tenants' is set to 'Yes'

**Rationale:**
Restricting tenant creation prevents unauthorized or uncontrolled deployment of resources and ensures that the organization retains control over its infrastructure.
User generation of shadow IT could lead to multiple, disjointed environments that can make it difficult for IT to manage and secure the organization's data, especially if other users in the organization began using these tenants for business purposes under the misunderstanding that they were secured by the organization's security team.

#### Remediation action:

1. Navigate to Microsoft 365 Entra admin center [https://entra.microsoft.com](https://entra.microsoft.com).
2. Click to expand **Identity** select **Users**.
3. Click **User settings**
4. Set **Restrict non-admin users from creating tenants** to **Yes**
5. Click Save.

#### Related links

* [Microsoft Entra admin center | Users | User settings](https://entra.microsoft.com/#view/Microsoft_AAD_UsersAndTenants/UserManagementMenuBlade/~/UserSettings/menuId/)
* [CIS Microsoft 365 Foundations Benchmark v5.0.0 - Page 167](https://www.cisecurity.org/benchmark/microsoft_365)

<!--- Results --->
%TestResult%