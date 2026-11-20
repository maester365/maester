function Test-MtAdGpoOwnerDistinctCount {
    <#
    .SYNOPSIS
    Inventories distinct GPO owners and the policies owned by each.

    .DESCRIPTION
    Combines the owner count and grouped details. Unresolved owners are listed
    separately and are not counted as an additional known owner.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOS-08'

    Inventories GPO owners and unresolved ownership for investigation.

    .LINK
    https://maester.dev/docs/tests/AD-GPOS-08
    #>
    [MaesterTest(
        Id                 = 'AD-GPOS-08',
        Title              = 'GPO owners should be investigated',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'access-control',
        ResourceType       = 'GroupPolicy',
        Severity           = 'Info',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOs) { throw 'GPO metadata could not be collected; owners cannot be inventoried.' }
    $gpos = @($state.GPOs | Where-Object { $null -ne $_ })
    $known = @($gpos | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.Owner) } | Group-Object Owner | Sort-Object Name)
    $unknown = @($gpos | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Owner) })
    $details = @(foreach ($group in $known) {
            [pscustomobject]@{ Owner = $group.Name; Count = $group.Count; Policies = ($group.Group.DisplayName | Sort-Object) -join ', ' }
        })
    if ($unknown.Count -gt 0) { $details += [pscustomobject]@{ Owner = $null; Count = $unknown.Count; Policies = ($unknown.DisplayName | Sort-Object) -join ', ' } }
    $summary = if ($gpos.Count -eq 0) { 'No GPOs were returned; no owners can be listed.' } else { "The $($gpos.Count) collected GPOs have $($known.Count) distinct known owners. Review ownership and delegation." }
    if ($unknown.Count -gt 0) { $summary += " Owners could not be resolved for $($unknown.Count) GPOs." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPOs' = $gpos.Count; 'Distinct known owners' = $known.Count; 'GPOs with unknown owners' = $unknown.Count }) -Details $details -Properties Owner, Count, Policies -Headers Owner, 'GPO count', GPOs
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
