function Test-MtAdGpoEnforcedCount {
    <#
    .SYNOPSIS
    Checks that GPO links are not enforced.

    .DESCRIPTION
    Passes when no configured enforcement flags exist, fails when any exist.
    Enabled enforced links override Block Inheritance; disabled links do not apply.
    Review intentional enforcement before changing it.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOL-04'

    Fails when any GPO link is enforced; review intended inheritance overrides.

    .LINK
    https://maester.dev/docs/tests/AD-GPOL-04
    #>
    [MaesterTest(
        Id                 = 'AD-GPOL-04',
        Title              = 'GPO links should not use enforcement',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'infrastructure',
        ResourceType       = 'GroupPolicy',
        Severity           = 'Low',
        UserImpact         = 'Low',
        ImplementationCost = 'Medium',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOLinks) { throw 'GPO links could not be collected; enforcement cannot be assessed.' }
    $links = @($state.GPOLinks | Where-Object { $null -ne $_ })
    if (@($links | Where-Object { $null -eq $_.IsEnforced }).Count -gt 0) { throw 'One or more GPO link enforcement states are unknown.' }
    $enforced = @($links | Where-Object { $true -eq $_.IsEnforced } | Sort-Object DistinguishedName, GpoGuid)
    $linksComplete = Test-MtAdGpoLinksComplete -State $state
    if ($enforced.Count -eq 0 -and -not $linksComplete) { throw 'GPO link collection is incomplete; absence of enforcement cannot be assessed.' }
    $active = @($enforced | Where-Object { $false -eq $_.IsDisabled })
    $disabled = @($enforced | Where-Object { $true -eq $_.IsDisabled })
    $unknownState = @($enforced | Where-Object { $null -eq $_.IsDisabled })
    $details = @(foreach ($link in $enforced) {
            [pscustomobject]@{
                Id = $link.GpoGuid
                Container = $link.DistinguishedName
                State = if ($null -eq $link.IsDisabled) { 'Unknown' } elseif ($link.IsDisabled) { 'Disabled' } else { 'Enabled' }
            }
        })
    $pass = $enforced.Count -eq 0
    $summary = if ($pass) { 'Well done. No configured enforcement flags were found.' }
    else { "$($enforced.Count) GPO links have configured enforcement flags; $($active.Count) are enabled overrides. Disabled links do not actively override inheritance. Review configured enforcement before changing it." }
    if ($unknownState.Count -gt 0) { $summary += " Enabled/disabled state is unknown for $($unknownState.Count) flagged links." }
    if (-not $linksComplete) { $summary += ' Link collection is incomplete; additional enforcement flags may exist.' }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Collected GPO links' = $links.Count; 'Enforced GPO links' = $enforced.Count; 'Enabled enforcement overrides' = $active.Count; 'Disabled links with enforcement flags' = $disabled.Count; 'Flagged links with unknown state' = $unknownState.Count; 'Link collection complete' = $linksComplete }) -Details $details -Properties Id, Container, State -Headers 'GPO Id', 'Linked container', 'Link state'
    Add-MtTestResultDetail -Result $result
    return $pass
}
