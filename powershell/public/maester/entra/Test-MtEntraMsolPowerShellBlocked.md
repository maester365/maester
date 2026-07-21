## Description

Checks if the legacy MSOnline (MSOL) PowerShell module is blocked from authenticating to the tenant.

## Why This Matters

The MSOnline (MSOL) and Azure AD PowerShell modules were retired by Microsoft and no longer receive security updates. Because they predate modern authentication controls, requests made through them can be a weaker, less-monitored path into a tenant's identity administration than the current Microsoft Graph PowerShell SDK.

The `blockMsolPowerShell` setting on the tenant's authorization policy lets an admin explicitly block authentication requests from the legacy MSOnline PowerShell module's service principal. This isn't enabled by default for every tenant, so it needs to be checked explicitly rather than assumed to already be in place — leaving it unblocked keeps an unsupported and unmonitored administrative access path open.

#### Remediation action:

1. Connect to Graph using **Connect-MgGraph -Scopes "Policy.ReadWrite.Authorization"**.
2. Run the following PowerShell command to review the current value:
```powershell
Get-MgPolicyAuthorizationPolicy | Select-Object BlockMsolPowerShell
```
3. If `BlockMsolPowerShell` is `$false`, block the legacy MSOnline PowerShell module:
```powershell
$authPolicy = Get-MgPolicyAuthorizationPolicy
Update-MgPolicyAuthorizationPolicy -AuthorizationPolicyId $authPolicy.Id -BlockMsolPowerShell:$true
```

#### Related links

* [Authorization policy in Entra ID | Microsoft Learn](https://learn.microsoft.com/en-us/graph/api/resources/authorizationpolicy)
* [Update-MgPolicyAuthorizationPolicy | Microsoft Learn - Graph PowerShell v1.0](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.identity.signins/update-mgpolicyauthorizationpolicy)

<!--- Results --->
%TestResult%
