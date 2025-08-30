<#
.SYNOPSIS
    Gets the Azure Tenant Root Management Group ID

.DESCRIPTION
    This function retrieves the Tenant Root Management Group ID by querying all management groups
    and finding the one with the display name "Tenant Root Group".

.EXAMPLE
    Test-AzureRootManagementGroup

    Returns the ID of the Tenant Root Management Group if found, otherwise returns $null.

.LINK
    https://maester.dev/docs/commands/Test-AzureRootManagementGroup
#>
function Get-AzureRootManagementGroup {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    try {
        $mgResponse = Invoke-MtAzureRequest `
            -RelativeUri "/providers/Microsoft.Management/managementGroups" `
            -ApiVersion "2020-05-01"

        $mgList = $mgResponse.value
    }
    catch {
        Write-Verbose "Error retrieving management groups: $_"
        return $null
    }

    $rootGroup = $mgList | Where-Object { $_.properties.displayName -eq "Tenant Root Group" }

    if (-not $rootGroup) {
        Write-Verbose "Tenant Root Group not found in management groups."
        return $null
    }

    return $rootGroup.name
}
