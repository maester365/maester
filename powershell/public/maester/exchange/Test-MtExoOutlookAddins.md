Users SHOULD NOT be allowed to install Outlook add-ins

Rationale: When users can install their own Outlook add-ins, it creates security risks. Malicious add-ins could access email content, exploit vulnerabilities, or facilitate data exfiltration through legitimate-looking add-ins.

#### Remediation action:

1. Connect to Exchange Online:
```powershell
Connect-ExchangeOnline
```

2. Get the current role assignment policy:
```powershell
Get-RoleAssignmentPolicy | Where-Object { $_.IsDefault }
```

3. Check which app-related roles are assigned:
```powershell
Get-ManagementRoleAssignment -RoleAssignee "Default Role Assignment Policy" | Where-Object { $_.Role -like "My*Apps" }
```

4. Remove the app installation permissions from the default policy:
```powershell
Remove-ManagementRoleAssignment -Identity "Default Role Assignment Policy-My Custom Apps" -Confirm:$false
Remove-ManagementRoleAssignment -Identity "Default Role Assignment Policy-My Marketplace Apps" -Confirm:$false
Remove-ManagementRoleAssignment -Identity "Default Role Assignment Policy-My ReadWriteMailbox Apps" -Confirm:$false
```

5. Verify the changes:
```powershell
Get-ManagementRoleAssignment -RoleAssignee "Default Role Assignment Policy" | Where-Object { $_.Role -like "My*Apps" }
```
The result should return no assignments.

#### Related links

* [Role-based access control in Exchange Online](https://learn.microsoft.com/en-us/exchange/permissions-exo/permissions-exo)
* [CIS Microsoft 365 Benchmark - 1.3.4 (L1) Ensure 'User owned apps and services' is restricted](https://www.cisecurity.org/benchmark/microsoft_365)
* [Microsoft Secure Score - Restrict user consent to applications](https://security.microsoft.com/securescore)

<!--- Results --->
%TestResult%