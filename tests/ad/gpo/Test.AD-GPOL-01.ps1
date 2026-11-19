function Test-MtAdGpoLinkedCount {
    <#
    .SYNOPSIS
    Inventories GPOs with at least one enabled link.
    .DESCRIPTION
    Uses normalized cached links. An enabled link does not prove effective policy
    application: security filtering, WMI filters and policy processing also matter.
    #>
    [MaesterTest(
        Id = 'AD-GPOL-01', Title = 'GPOs with enabled links should be investigated',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'GroupPolicy', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOs -or $null -eq $state.GPOLinks) { throw 'GPO metadata or links could not be collected; enabled links cannot be inventoried.' }
    $gpos = @($state.GPOs | Where-Object { $null -ne $_ })
    if (@($gpos | Where-Object { [string]::IsNullOrWhiteSpace([string]$_.Id) }).Count -gt 0) { throw 'One or more GPO identifiers are unknown; enabled links cannot be inventoried.' }
    $links = @($state.GPOLinks | Where-Object { $null -ne $_ })
    if (@($links | Where-Object { $null -eq $_.IsDisabled -or [string]::IsNullOrWhiteSpace([string]$_.GpoGuid) }).Count -gt 0) { throw 'One or more GPO links have unknown state or target.' }
    $enabledIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($link in @($links | Where-Object { $false -eq $_.IsDisabled })) { $null = $enabledIds.Add(([string]$link.GpoGuid).Trim('{}')) }
    $linked = @($gpos | Where-Object { $enabledIds.Contains(([string]$_.Id).Trim('{}')) } | Sort-Object DisplayName)
    $summary = if ($linked.Count -eq 0) { 'No collected GPO has an enabled link.' } else { "$($linked.Count) of $($gpos.Count) GPOs have at least one enabled link. Enabled links alone do not establish effective policy application." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPOs' = $gpos.Count; 'GPOs with enabled links' = $linked.Count; 'GPOs without enabled links' = $gpos.Count - $linked.Count }) -Details $linked -Properties DisplayName, Id -Headers GPO, Id
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
