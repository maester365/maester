<#
.SYNOPSIS
    Returns all Azure Management Group names in the tenant

.DESCRIPTION
    This function retrieves all Azure Management Group names by querying the Azure Management API.
    Returns an array of management group names that are accessible to the current user.

.EXAMPLE
    Get-AzureManagementGroup

    Returns all management group names in the tenant.

.LINK
    https://maester.dev/docs/commands/Get-AzureManagementGroup
#>
function Get-AzureManagementGroup {
    [CmdletBinding()]
    [OutputType([string])]
    param()

    if (!(Test-MtConnection Azure)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedAzure
        return $null
    }

    try {
        $ManagementGroups = Invoke-MtAzureRequest `
            -RelativeUri "/providers/Microsoft.Management/managementGroups" `
            -ApiVersion "2020-05-01" |
            Select-Object -ExpandProperty value

    }
    catch {
        Write-Verbose "Error retrieving management groups: $_"
        return $null
    }

    return [string[]]$ManagementGroups.name
}
