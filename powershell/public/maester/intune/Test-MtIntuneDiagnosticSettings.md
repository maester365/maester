This test checks for the existence of Intune Diagnostic settings collecting Intune Audit Logs.

#### Test Prerequisites

For this test to run, the executing principal must have permissions to read Intune diagnostic settings in Azure (`microsoft.intune/diagnosticSettings/read` action). This typically requires at least the 'Monitoring Reader' or 'Reader' Azure role assigned at the subscription where the target Intune Log Analytics workspace or storage account resides.

Alternatively, you can create a custom RBAC role with the following snippet:

```powershell
# Get the subscription ID and user ID from the current context. Change if necessary.
$SubscriptionId = "$((Get-AzContext).Subscription.Id)"
$UserId = (Get-AzADUser -UserPrincipalName (Get-AzContext).Account.Id).Id

$CustomRole = @{
    Name = 'Intune Diagnostic Settings Reader'
    Description = 'Can read Intune diagnostic settings only'
    Actions = @('microsoft.intune/diagnosticSettings/read')
    NotActions = @()
    AssignableScopes = @("/subscriptions/$SubscriptionId")
}

New-AzRoleDefinition -Role $CustomRole

# Assign the custom role at subscription level
New-AzRoleAssignment -ObjectId $UserId -RoleDefinitionName 'Intune Diagnostic Settings Reader' -Scope "/subscriptions/$SubscriptionId"
```

#### Remediation action

* Check the following Microsoft learn article to [Send Intune log data to Azure Storage, Event Hubs, or Log Analytics](https://learn.microsoft.com/en-us/intune/intune-service/fundamentals/review-logs-using-azure-monitor).

* Existing diagnostic settings can be viewed within the [Intune Diagnostics settings blade](https://intune.microsoft.com/#view/Microsoft_Intune_DeviceSettings/TenantAdminMenu/~/diagnostics).


<!--- Results --->
%TestResult%