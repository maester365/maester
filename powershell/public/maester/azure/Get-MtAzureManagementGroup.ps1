<#
.SYNOPSIS
    Returns all Azure Management Groups in the tenant

.DESCRIPTION
    This function retrieves all Azure Management Groups by querying the Azure Management API.
    Returns an array of management groups that are accessible to the current user.

    * [Quickstart: Create a management group](https://learn.microsoft.com/en-us/azure/governance/management-groups/create-management-group-portal)
    * [Azure Management Groups Overview](https://docs.microsoft.com/en-us/azure/governance/management-groups/overview)

.EXAMPLE
    Get-MtAzureManagementGroup

    Returns all management groups in the tenant.

.LINK
    https://maester.dev/docs/commands/Get-MtAzureManagementGroup
#>
function Get-MtAzureManagementGroup {
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
