function Test-MtAdGpoWmiFilterCount {
    <#
    .SYNOPSIS
    Inventories GPOs with WMI filters, including their filter references.
    .DESCRIPTION
    Combines counts and details for non-empty WMI filter references. The inventory
    requires investigation, not a pass/fail judgement on targeting.
    #>
    [MaesterTest(
        Id = 'AD-GPOS-02', Title = 'GPO WMI filters should be investigated',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'GroupPolicy', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOs) { throw 'GPO metadata could not be collected; WMI filters cannot be inventoried.' }
    $gpos = @($state.GPOs | Where-Object { $null -ne $_ })
    $filtered = @($gpos | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.WmiFilter) } | Sort-Object DisplayName)
    $summary = if ($filtered.Count -eq 0) { 'No collected GPO has a WMI filter reference.' } else { "$($filtered.Count) of $($gpos.Count) GPOs have WMI filter references. Review targeting and filter performance." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPOs' = $gpos.Count; 'GPOs with WMI filters' = $filtered.Count }) -Details $filtered -Properties DisplayName, Id, WmiFilter -Headers GPO, Id, 'WMI filter'
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
