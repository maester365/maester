function Get-MtEntraHardDeletionProtectedObject {
    <#
    .SYNOPSIS
    Returns the users, groups, applications and service principals that have Hard Deletion Protection.

    .DESCRIPTION
    Queries Microsoft Graph beta for objects whose isHardDeleteProtectionEnabled property is true, both
    among active objects and among soft-deleted ones. Each result has Type, Id, DisplayName and State
    ('Active' or 'Soft deleted').

    The two reads happen one after the other, so an object can show up in both when it is soft deleted or
    restored between them. The function returns such an object once, with the State 'Active or soft deleted',
    and does not claim that either read is newer.

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

    $Observed = [System.Collections.Generic.List[object]]::new()
    foreach ($Source in $Sources) {
        foreach ($State in 'Active', 'Soft deleted') {
            $Path = if ($State -eq 'Active') { $Source.Path } else { $Source.Deleted }
            $Objects = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri $Path `
                    -Filter 'isHardDeleteProtectionEnabled eq true' -Select @('id', 'displayName') `
                    -ErrorAction Stop
            )
            foreach ($Object in $Objects) {
                $Observed.Add([pscustomobject]@{
                        Type        = $Source.Type
                        Id          = [string]$Object.id
                        DisplayName = [string]$Object.displayName
                        State       = $State
                    })
            }
        }
    }

    foreach ($Group in @($Observed | Group-Object -Property Type, Id)) {
        $States = @($Group.Group.State | Select-Object -Unique)
        [pscustomobject]@{
            Type        = $Group.Group[0].Type
            Id          = $Group.Group[0].Id
            DisplayName = $Group.Group[0].DisplayName
            State       = if ($States.Count -eq 1) { $States[0] } else { 'Active or soft deleted' }
        }
    }
}
