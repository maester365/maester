<#
.SYNOPSIS
    Returns a boolean depending on the configuration.

.DESCRIPTION
    Checks the status of Azure Artifacts storage, Azure DevOps provides 2 GiB of free storage for each organization.
    Once your organization reaches the maximum storage limit, you won't be able to publish new artifacts.
    To continue, you can either delete some of your existing artifacts or increase your storage limit.

    https://learn.microsoft.com/en-us/azure/devops/artifacts/how-to/delete-and-recover-packages?view=azure-devops&tabs=nuget#delete-packages-automatically-with-retention-policies
    https://learn.microsoft.com/en-us/azure/devops/organizations/billing/set-up-billing-for-your-organization-vs?view=azure-devops#set-up-billing
    https://learn.microsoft.com/en-us/azure/devops/artifacts/reference/limits?view=azure-devops

.EXAMPLE
    ```
    Test-AzdoOrganizationStorageUsage
    ```

    Returns a boolean depending on the configuration.

.LINK
    https://maester.dev/docs/commands/Test-AzdoOrganizationStorageUsage
#>
function Test-AzdoOrganizationStorageUsage {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    if ($null -eq (Get-ADOPSConnection)['Organization']) {
        Write-Verbose 'Not connected to Azure DevOps'
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason 'Not connected to Azure DevOps'
        return $null
    }

    $StorageUsage = Get-ADOPSOrganizationCommerceMeterUsage -MeterId '3efc2e47-d73e-4213-8368-3a8723ceb1cc' -Force
    $availableQuantity = $StorageUsage.availableQuantity
    if ($availableQuantity -eq [double]::MaxValue) {
        $MaxQuantity = 'Unlimited'
    } else {
        $MaxQuantity = "$($StorageUsage.maxQuantity) GB"
    }
    # As regions have different ways to declare decimal separators, we will query the culture of the OS.
    $DecimalSeparator = $((Get-Culture).NumberFormat.CurrencyDecimalSeparator)

    if ($availableQuantity -lt [double]::Parse("0$DecimalSeparator`1")) {
        $resultMarkdown = "Your storage is exceeding the usage limit or close to. '$availableQuantity' GB available."
        $result = $false
    } else {
        $CurrentQuantity = $StorageUsage.currentQuantity ? $StorageUsage.currentQuantity : 0
        $resultMarkdown =
@'
You are not exceeding or approaching your storage usage limit.

Current usage: {0} GB

Max quantity: {1}
'@ -f $CurrentQuantity, $MaxQuantity
        $result = $true
    }

    Add-MtTestResultDetail -Result $resultMarkdown

    return $result
}