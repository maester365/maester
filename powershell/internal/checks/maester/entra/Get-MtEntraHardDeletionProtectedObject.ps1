function Get-MtEntraHardDeletionProtectedObject {
    <#
    .SYNOPSIS
    Returns the users, groups, applications and service principals that have Hard Deletion Protection.

    .DESCRIPTION
    Queries Microsoft Graph beta for objects whose isHardDeleteProtectionEnabled property is true, both
    among active objects and among soft-deleted ones. Each result has Type, Id, DisplayName and State
    ('Active' or 'Soft deleted').

    .EXAMPLE
    Get-MtEntraHardDeletionProtectedObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $Sources = @(
        @{ Type = 'User'; Path = 'users'; Deleted = 'directory/deletedItems/microsoft.graph.user' }
        @{ Type = 'Group'; Path = 'groups'; Deleted = 'directory/deletedItems/microsoft.graph.group' }
        @{ Type = 'Application'; Path = 'applications'; Deleted = 'directory/deletedItems/microsoft.graph.application' }
        @{
            Type    = 'ServicePrincipal'
            Path    = 'servicePrincipals'
            Deleted = 'directory/deletedItems/microsoft.graph.servicePrincipal'
        }
    )

    foreach ($Source in $Sources) {
        foreach ($State in 'Active', 'Soft deleted') {
            $Path = if ($State -eq 'Active') { $Source.Path } else { $Source.Deleted }
            $Objects = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri $Path `
                    -Filter 'isHardDeleteProtectionEnabled eq true' -Select @('id', 'displayName')
            )
            foreach ($Object in $Objects) {
                [pscustomobject]@{
                    Type        = $Source.Type
                    Id          = [string]$Object.id
                    DisplayName = [string]$Object.displayName
                    State       = $State
                }
            }
        }
    }
}
