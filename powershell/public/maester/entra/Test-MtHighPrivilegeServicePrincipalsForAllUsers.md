This test checks if any of the following high-privilege, first-party Microsoft service principals allow sign-in from any user instead of requiring explicit assignment:

- Microsoft Azure PowerShell
- Microsoft Azure CLI
- Microsoft Graph Command Line Tools (used by the Microsoft Graph PowerShell SDK and Microsoft Graph CLI)
- Graph Explorer
- Azure Active Directory PowerShell (legacy)
- Microsoft Teams PowerShell Cmdlets (used by the `MicrosoftTeams` module)
- Microsoft Exchange Online PowerShell (used by the `ExchangeOnlineManagement` module)
- Microsoft SharePoint Online Management Shell
- Power Platform CLI (`pac`)

These apps are pre-consented in most tenants and carry broad delegated permissions to Microsoft Graph, Azure Resource Manager, or their respective workload (Exchange Online, SharePoint Online, Teams, Power Platform). Left open to all users, any compromised or malicious account can use them, without any further consent prompt, to enumerate directory data and resources, or to administer that workload directly - a common first step in privilege escalation and data exfiltration. It is recommended to set 'Assignment required?' to Yes for these applications and explicitly assign only the users or groups who need them.

#### Remediation action

1. Open each flagged application below in the Microsoft Entra admin center and set 'Assignment required?' to Yes under **Properties**.
2. Assign the users or groups who need access under **Users and groups**.
3. Alternatively, use Microsoft Graph PowerShell:
```powershell
Connect-MgGraph -Scopes 'Application.ReadWrite.All'
$sp = Get-MgServicePrincipal -Filter "appId eq '<AppId>'"
Update-MgServicePrincipal -ServicePrincipalId $sp.Id -AppRoleAssignmentRequired:$true
```
4. If desired, review the application's sign-in logs first to identify who was using it before locking it down.

<!--- Results --->

%TestResult%
