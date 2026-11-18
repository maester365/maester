function Get-MtEntraHardDeletionProtectedObject {
    <#
    .SYNOPSIS
    Returns the users, groups, applications and service principals that have Hard Deletion
    Protection.

    .DESCRIPTION
    Queries Microsoft Graph beta for objects whose isHardDeleteProtectionEnabled property is
    true, both among active objects and among soft-deleted ones. Each result has Type, Id,
    DisplayName and State ('Active' or 'Soft deleted').

    The reads happen one after the other, so the scan is not a snapshot. An object that is soft
    deleted or restored while it runs can show up in both reads, or in neither. The function
    returns an object seen in both reads once, with the State 'Active or soft deleted', and does
    not claim that either read is newer. An object seen in neither read is missed.

    .EXAMPLE
    Get-MtEntraHardDeletionProtectedObject
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    $DeletedRoot = 'directory/deletedItems/microsoft.graph'
    $Sources = @(
        @{ Type = 'User'; Path = 'users'; Deleted = "$DeletedRoot.user" }
        @{ Type = 'Group'; Path = 'groups'; Deleted = "$DeletedRoot.group" }
        @{ Type = 'Application'; Path = 'applications'; Deleted = "$DeletedRoot.application" }
        @{
            Type    = 'ServicePrincipal'
            Path    = 'servicePrincipals'
            Deleted = "$DeletedRoot.servicePrincipal"
        }
    )

    $Observed = [System.Collections.Generic.List[object]]::new()
    foreach ($Source in $Sources) {
        foreach ($State in 'Active', 'Soft deleted') {
            $Path = if ($State -eq 'Active') { $Source.Path } else { $Source.Deleted }
            $Objects = @(
                Invoke-MtGraphRequest -ApiVersion 'beta' -RelativeUri $Path `
                    -Filter 'isHardDeleteProtectionEnabled eq true' `
                    -Select @('id', 'displayName') -ErrorAction Stop
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
