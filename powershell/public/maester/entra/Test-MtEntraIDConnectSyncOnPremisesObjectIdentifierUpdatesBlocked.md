Checks if the temporary bypass for onPremisesObjectIdentifier updates is disabled

Starting July 1, 2026, Microsoft Entra ID adds extra protections for hard match operations during on-premises directory synchronization. These protections help prevent an on-premises Active Directory object from taking over the wrong cloud account when the target account is risky to reassociate. A hard match can be blocked when the target cloud account already has onPremisesObjectIdentifier set, is assigned a privileged Microsoft Entra role, or is eligible for a privileged Microsoft Entra role.

If you can't remediate an affected object before enforcement, Microsoft Entra ID lets you enable the tenant-level feature flag `allowOnPremUpdateOfOnPremisesObjectIdentifierEnabled` as a temporary bypass. This flag is disabled by default.

Enabling this feature flag reduces the protection provided by hard match security enforcement for the entire tenant, not just the object you're remediating. It should only be used as a temporary bypass for a validated migration, recovery, or consolidation scenario, and disabled again as soon as remediation is complete. Leaving it enabled indefinitely re-opens the risk of an on-premises object taking over the wrong, potentially privileged, cloud account.

#### Remediation action:

To check and disable the temporary bypass using Graph PowerShell:

1. Connect to Graph using **Connect-MgGraph -Scopes "OnPremDirectorySynchronization.ReadWrite.All"**.
2. Run the following PowerShell command to review the current value:
```
$onPremSync = Get-MgDirectoryOnPremiseSynchronization
$onPremSync.Features | fl
```
3. If `AllowOnPremUpdateOfOnPremisesObjectIdentifierEnabled` is `$true` and remediation is complete, disable it:
```
$onPremSync = Get-MgDirectoryOnPremiseSynchronization
$onPremSync.Features.AllowOnPremUpdateOfOnPremisesObjectIdentifierEnabled = $false
Update-MgDirectoryOnPremiseSynchronization `
    -OnPremisesDirectorySynchronizationId $onPremSync.Id `
    -Features $onPremSync.Features
```

#### Related links

* [Configure Microsoft Entra Connect for an existing tenant - Temporarily allow onPremisesObjectIdentifier updates | Microsoft Learn](https://learn.microsoft.com/en-us/entra/identity/hybrid/connect/how-to-connect-install-existing-tenant#temporarily-allow-onpremisesobjectidentifier-updates)
* [Update-MgDirectoryOnPremiseSynchronization | Microsoft Learn - Graph PowerShell v1.0](https://learn.microsoft.com/en-us/powershell/module/microsoft.graph.identity.directorymanagement/update-mgdirectoryonpremisesynchronization)

<!--- Results --->
%TestResult%

