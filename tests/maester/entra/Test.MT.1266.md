Accidental deletion prevention should be enabled for on-premises directory synchronization.

Microsoft Entra Connect Sync can stop an export to Microsoft Entra ID that would delete more objects than a threshold. The feature is enabled with a threshold of 500 objects when Microsoft Entra Connect is installed, but it can be disabled, and it often stays disabled after it was turned off to let a large, intended deletion through.

Without it, one on-premises change deletes every synchronized object it affects in a single sync cycle. Common causes are a filtering change that drops an OU or domain, objects moved out of scope, or an OU that's renamed. An attacker who controls the on-premises directory can use the same path to delete cloud users and groups. The threshold is stored in the tenant and can only be changed with a Microsoft Entra credential, so control of the on-premises directory alone isn't enough to turn it off.

The test reads the tenant setting that Microsoft Entra Connect Sync uses. It's skipped when the tenant doesn't synchronize from an on-premises directory. Reading the setting needs a delegated connection with the Global Administrator role. Microsoft Entra Cloud Sync sets accidental deletion prevention on each of its configurations, and this test doesn't check those.

#### Remediation action

To check and enable accidental deletion prevention on the Microsoft Entra Connect server:

1. Sign in to the Microsoft Entra Connect server and open PowerShell as an administrator.
2. Review the current setting:

```powershell
Get-ADSyncExportDeletionThreshold -AADUserName "<UserPrincipalName>"
```

3. Enable it with a threshold that fits the size of your directory, for example 500 objects:

```powershell
Enable-ADSyncExportDeletionThreshold -DeletionThreshold 500 -AADUserName "<UserPrincipalName>"
```

4. If large, intended deletions are frequent, raise the threshold instead of disabling the feature. If you disable it for one export, enable it again as soon as that export has run.

#### Related links

* [Microsoft Entra Connect Sync: Prevent accidental deletes | Microsoft Learn](https://learn.microsoft.com/entra/identity/hybrid/connect/how-to-connect-sync-feature-prevent-accidental-deletes)
* [onPremisesAccidentalDeletionPrevention resource type | Microsoft Learn](https://learn.microsoft.com/graph/api/resources/onpremisesaccidentaldeletionprevention)
* [Microsoft Entra Cloud Sync: Accidental deletes | Microsoft Learn](https://learn.microsoft.com/entra/identity/hybrid/cloud-sync/how-to-accidental-deletes)

<!--- Results --->
%TestResult%
