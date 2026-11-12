function Get-MtEntraAgentHighRiskGraphPermission {
    <#
    .SYNOPSIS
    Returns the Microsoft Graph application permissions MT.1223 treats as high risk on agent identities.

    .DESCRIPTION
    The single source of the MT.1223 permission list. Each key is a permission name and each value is
    its attack path: Direct when the permission can grant privilege on its own, Indirect when it opens
    a path to privilege. Get-MtEntraAgentHighRiskGraphPermissionFinding uses it to find the
    permissions, and the agent blocked permissions drift test reads it so the two cannot drift apart.
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    @{
        'AdministrativeUnit.ReadWrite.All'                      = 'Indirect'
        'Application.ReadUpdate.All'                            = 'Indirect'
        'DeviceManagementConfiguration.ReadWrite.All'          = 'Indirect'
        'DeviceManagementRBAC.ReadWrite.All'                   = 'Indirect'
        'Policy.ReadWrite.ConditionalAccess'                   = 'Direct'
        'PrivilegedAccess.ReadWrite.AzureADGroup'              = 'Direct'
        'PrivilegedAssignmentSchedule.ReadWrite.AzureADGroup'  = 'Direct'
        'PrivilegedEligibilitySchedule.ReadWrite.AzureADGroup' = 'Indirect'
        'RoleAssignmentSchedule.ReadWrite.Directory'           = 'Direct'
        'RoleEligibilitySchedule.ReadWrite.Directory'          = 'Indirect'
        'RoleManagementPolicy.ReadWrite.AzureADGroup'          = 'Indirect'
        'RoleManagementPolicy.ReadWrite.Directory'             = 'Indirect'
    }
}
