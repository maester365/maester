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

<details>
  <summary>(Optional) Grant permissions to Exchange Online</summary>
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
</details>

<details>
  <summary>(Optional) Grant permissions to Teams</summary>
### (Optional) Grant permissions to Teams

The Teams Role Based Access Control (RBAC) implementation utilizes service specific roles that apply to an application and the below configuration allows the authorization chain to the App Registration you created in the previous steps.

> The Teams permissions are necessary to support tests that validate [Teams configurations](https://maester.dev/docs/installation#installing-azure-exchange-online-and-teams-modules).

- Open Roles and administrators
- Search and select **Teams Reader**
- Select **Add assigment**
- Select **No member selected**
- Search for the name of previously created application
- Select previously created application and select **Select** to confirm
- Select **Next** to confirm
- Ensure that **Active** and **Permanently assigned** are ticked
- Enter **Justification**
- Select **Assign** to confirm

</details>

<details>
  <summary>(Optional) Grant permissions to Azure</summary>
### (Optional) Grant permissions to Azure

The Azure Role Based Access Control (RBAC) implementation utilizes Uniform Resource Names (URN) with a "/" separator for heirarchical scoping. There exists resources within the root (e.g., "/") scope that Microsoft retains strict control over by limiting supported interactions. As a Global Administrator you can [elevate access](https://learn.microsoft.com/en-us/azure/role-based-access-control/elevate-access-global-admin?tabs=powershell) to become authorized for these limited interactions.

> The Azure RBAC permissions are necessary to support tests that validate [Azure configurations](https://maester.dev/docs/installation#installing-azure-and-exchange-online-modules), such as the [CISA tests](https://maester.dev/docs/tests/cisa/entra#:~:text=Test%2DMtCisaDiagnosticSettings).

The following PowerShell script will enable you, with a Global Administrator role assignment, to:
- Identify the Service Principal Object ID that will be authorized as a Reader (Enterprise app Object ID)
- Install the necessary Az module and prompt for connection
- Elevate your account access to the root scope
- Create a role assignment for Reader access over the Root Scope
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

#Assign permissions to Enterprise App
New-AzRoleAssignment -ObjectId $servicePrincipal -Scope "/" -RoleDefinitionName "Reader" -ObjectType "ServicePrincipal"
New-AzRoleAssignment -ObjectId $servicePrincipal -Scope "/providers/Microsoft.aadiam" -RoleDefinitionName "Reader" -ObjectType "ServicePrincipal"

#Remove root scope access
$assignment = Get-AzRoleAssignment -RoleDefinitionId 18d7d88d-d35e-4fb5-a5c3-7773c20a72d9|?{$_.Scope -eq "/" -and $_.SignInName -eq (Get-AzContext).Account.Id}
$deleteAssignment = Invoke-AzRestMethod -Path "$($assignment.RoleAssignmentId)?api-version=2018-07-01" -Method DELETE
```
</details>

<details>
  <summary>(Optional) Grant permissions to SharePoint Online</summary>
### (Optional) Grant permissions to SharePoint Online

SharePoint Online tests require the **PnP.PowerShell** module and a dedicated PnP Entra ID app registration. The standard Maester app registration does not cover SharePoint tenant admin operations — PnP requires its own app with `Sites.FullControl.All` permissions.

> The SharePoint Online permissions are necessary to support tests that validate [SharePoint Online configurations](https://maester.dev/docs/tests/cisa/spo), such as the CISA SharePoint baseline controls.

#### Install PnP.PowerShell

```powershell
Install-Module PnP.PowerShell -Scope CurrentUser
```

#### Register the PnP Entra ID app

PnP provides a built-in cmdlet to create the required app registration for interactive login:

```powershell
Register-PnPEntraIDAppForInteractiveLogin -ApplicationName "Maester PnP" -Tenant [yourtenant].onmicrosoft.com -SharePointDelegatePermissions "AllSites.FullControl"
```

This will:
- Create an Entra ID app registration with the required delegated permissions
- Prompt you to authenticate and provide consent
- Output the **Client ID** you will need for `Connect-Maester`

> **Note:** `AllSites.FullControl` (delegated) is the minimum permission required by PnP for tenant admin cmdlets like `Get-PnPTenant`. There is no read-only equivalent.
>
> **Important:** After registering the app, open a **new PowerShell session** before running `Connect-Maester`, as the registration process loads PnP assemblies that can conflict with Microsoft Graph.

#### Connect to SharePoint Online

Use the Client ID from the previous step when connecting:

```powershell
Connect-Maester -Service Graph,SharePointOnline -SharePointClientId "<Client ID from Register-PnPEntraIDAppForInteractiveLogin>"
```

For device code flow (e.g. non-interactive sessions):

```powershell
Connect-Maester -Service Graph,SharePointOnline -SharePointClientId "<Client ID>" -UseDeviceCode
```

</details>

<details>
  <summary>(Optional) Grant Dataverse permissions for Copilot Studio tests</summary>
### (Optional) Grant Dataverse permissions for Copilot Studio

Dataverse access is required for the Copilot Studio security tests (MT.1113–MT.1122) that evaluate Copilot Studio agent configurations.

#### Create an Application User in Power Platform

1. Go to the [Power Platform Admin Center](https://admin.powerplatform.microsoft.com) → select your environment → **Settings** → **Users + permissions** → **Application users**
2. Click **New app user** → **Add an app** → select the app registration created above
3. Select the correct **Business unit**
4. Assign a security role with read access:
   - **Basic User** for simplicity, or
   - A **custom role** (e.g. `Maester Security Reader`) with Organization-level **Read** on: **Agent** (`bot`), **Agent component** (`botcomponent`), **User** (`systemuser`), and **Connection Reference** (`connectionreference`)
5. Click **Create**

#### Configure Maester

Add the environment URL to `maester-config.json`:

```json
{
  "GlobalSettings": {
    "DataverseEnvironmentUrl": "https://org12345.crm.dynamics.com"
  }
}
```

</details>