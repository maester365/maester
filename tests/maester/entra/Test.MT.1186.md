This test checks if any of the following high-privilege, first-party Microsoft service principals allow sign-in from any user instead of requiring explicit assignment:

- Microsoft Azure PowerShell
- Microsoft Azure CLI and Azure Developer CLI (`azd`) - both currently use the same application ID
- Microsoft Graph Command Line Tools (used by the Microsoft Graph PowerShell SDK and Microsoft Graph CLI)
- Graph Explorer
- Azure Active Directory PowerShell (legacy)
- Microsoft Teams PowerShell Cmdlets (used by the `MicrosoftTeams` module)
- Microsoft Exchange Online PowerShell (used by the `ExchangeOnlineManagement` module)
- Microsoft SharePoint Online Management Shell
- Power Platform CLI (`pac`)

These apps are pre-consented in most tenants and carry broad delegated permissions to Microsoft Graph, Azure Resource Manager, or their respective workload (Exchange Online, SharePoint Online, Teams, Power Platform). Left open to all users, any compromised or malicious account can use them, without any further consent prompt, to enumerate directory data and resources, or to administer that workload directly - a common first step in privilege escalation and data exfiltration. It is recommended to set 'Assignment required?' to Yes for these applications and explicitly assign only the users or groups who need them.

A first-party application can still be used even when its service principal is not visible in the tenant. A missing service principal is therefore reported as needing attention because the assignment requirement cannot be enforced until the service principal is created.

#### Remediation action

1. Review the application's sign-in logs to identify the users who need access.
2. If a flagged application is reported as **Service principal missing**, create it with Microsoft Graph PowerShell:

   ```powershell
   Connect-MgGraph -Scopes 'Application.ReadWrite.All'
   $appId = '<AppId>'
   $sp = Get-MgServicePrincipal -Filter "appId eq '$appId'"
   if (-not $sp) {
       $sp = New-MgServicePrincipal -AppId $appId
   }
   ```

3. Assign the approved users or groups under **Users and groups**.
4. Set **Assignment required?** to **Yes** under **Properties**, or use Microsoft Graph PowerShell:

   ```powershell
   Update-MgServicePrincipal -ServicePrincipalId $sp.Id -AppRoleAssignmentRequired:$true
   ```

<!--- Results --->

%TestResult%
