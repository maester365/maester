import GraphPermissions from '../sections/permissions.md';
import PrivilegedPermissions from '../sections/privilegedPermissions.md';

### Create an Entra Application

- Open [Entra admin center](https://entra.microsoft.com) > **Identity** > **Applications** > **App registrations**
  - Tip: [enappreg.cmd.ms](https://enappreg.cmd.ms) is a shortcut to the App registrations page.
- Select **New registration**
- Enter a name for the application (e.g. `Maester DevOps Account`)
- Select **Register**

### Grant permissions to Microsoft Graph

- Open the application you created in the previous step
- Select **API permissions** > **Add a permission**
- Select **Microsoft Graph** > **Application permissions**
- Search for each of the permissions and check the box next to each permission:
  <GraphPermissions/>
- Optionally, search for each of the permissions if you want to allow privileged permissions:
  <PrivilegedPermissions/>
- Select **Add permissions**
- Select **Grant admin consent for [your organization]**
- Select **Yes** to confirm

### (Optional) Grant permissions to Exchange Online

The Exchange Online Role Based Access Control (RBAC) implementation utilizes service specific roles that apply to an application and the below configuration allows the authorization chain to the App Registration you created in the previous steps.

> The Exchange Online permissions are necessary to support tests that validate [Exchange Online configurations](https://maester.dev/docs/installation#installing-azure-and-exchange-online-modules), such as the [CISA tests](https://maester.dev/docs/tests/cisa/exo).

- Open the application you created in the previous step
- Select **API permissions** > **Add a permission**
- Select **APIs that my organization uses** > search for **Office 365 Exchange Online** > **Application permissions**
- Search for `Exchange.ManageAsApp`
- Select **Add permissions**
- Select **Grant admin consent for [your organization]**
- Select **Yes** to confirm
- Connect to the Exchange Online Management tools and use the following to set the appropriate permissions:

```PowerShell
New-ServicePrincipal -AppId <Application ID> -ObjectId <Object ID> -DisplayName <Name>
New-ManagementRoleAssignment -Role "View-Only Configuration" -App <DisplayName from previous command>
```

### (Optional) Grant permissions to Azure

The Azure Role Based Access Control (RBAC) implementation utilizes Uniform Resource Names (URN) with a "/" separator for heirarchical scoping. There exists resources within the root (e.g., "/") scope that Microsoft retains strict control over by limiting supported interactions. As a Global Administrator you can [elevate access](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin?tabs=powershell) to become authorized for these limited interactions.

> The Azure RBAC permissions are necessary to support tests that validate [Azure configurations](https://maester.dev/docs/installation#installing-azure-and-exchange-online-modules), such as the [CISA tests](https://maester.dev/docs/tests/cisa/entra#:~:text=Test%2DMtCisaDiagnosticSettings).

The following PowerShell script will enable you, with a Global Administrator role assignment, to:
- Identify the Service Principal Object ID that will be authorized as a Reader and the Subscription ID to authorize for
- Install the necessary Az module and prompt for connection
- Elevate your account access to the root scope
- Create a role assignment for Reader access over the Subscription and objects within
- Create a role assignment for Reader access over the Entra ID (i.e., [aadiam provider](https://learn.microsoft.com/en-us/azure/role-based-access-control/permissions/identity#microsoftaadiam))
- Identify the role assignment authorizing your account access to the root scope
- Delete the root scope role assignment for your account

```powershell
$servicePrincipal = "<Object ID of the Entra App>"
$subscription = "<Subscription ID>"
Install-Module Az.Accounts -Force
Install-Module Az.Resources -Force
Connect-AzAccount
#Elevate to root scope access
$elevateAccess = Invoke-AzRestMethod -Path "/providers/Microsoft.Authorization/elevateAccess?api-version=2015-07-01" -Method POST
New-AzRoleAssignment -ObjectId $servicePrincipal -Scope "/subscriptions/$subscription" -RoleDefinitionName "Reader" -ObjectType "ServicePrincipal"
New-AzRoleAssignment -ObjectId $servicePrincipal -Scope "/providers/Microsoft.aadiam" -RoleDefinitionName "Reader" -ObjectType "ServicePrincipal"
#Remove root scope access
$assignment = Get-AzRoleAssignment -RoleDefinitionId 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9|?{$_.Scope -eq "/" -and $_.SignInName -eq (Get-AzContext).Account.Id}
$deleteAssignment = Invoke-AzRestMethod -Path "$($assignment.RoleAssignmentId)?api-version=2018-07-01" -Method DELETE
```
