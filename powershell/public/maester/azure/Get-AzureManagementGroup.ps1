<#
.SYNOPSIS
    Returns all Azure Management Groups in the tenant

.DESCRIPTION
    This function retrieves all Azure Management Groups by querying the Azure Management API.
    Returns an array of management groups that are accessible to the current user.

.EXAMPLE
    Get-AzureManagementGroup

    Returns all management groups in the tenant.

.LINK
    https://maester.dev/docs/commands/Get-AzureManagementGroup
#>
function Get-AzureManagementGroup {
    [CmdletBinding()]
    [OutputType([PSCustomObject[]])]
    param()

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

    return $ManagementGroups
}
