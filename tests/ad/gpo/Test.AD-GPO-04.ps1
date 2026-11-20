function Test-MtAdGpoUnlinkedCount {
    <#
    .SYNOPSIS
    Checks that every GPO has a link to a domain, OU or site.

    .DESCRIPTION
    Compares GPO identifiers with collected link references, including disabled
    links. Settings status does not establish whether a GPO is linked.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPO-04'

    Fails when a GPO has no link to a domain, OU or site, including disabled links.

    .LINK
    https://maester.dev/docs/tests/AD-GPO-04
    #>
    [MaesterTest(
        Id                 = 'AD-GPO-04',
        Title              = 'GPOs should have at least one link',
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
    if ($null -eq $state -or $null -eq $state.GPOs -or $null -eq $state.GPOLinks) { throw 'GPO metadata or links were not retrieved; unlinked GPOs cannot be assessed.' }
    if (-not (Test-MtAdGpoLinksComplete -State $state)) { throw 'GPO link collection is incomplete; missing links cannot be assessed conclusively.' }
    $gpos = @($state.GPOs | Where-Object { $null -ne $_ })
    $linkedIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($link in @($state.GPOLinks | Where-Object { $null -ne $_ })) {
        if ($null -ne $link.GpoGuid) { $null = $linkedIds.Add(([string]$link.GpoGuid).Trim('{}')) }
        foreach ($match in [regex]::Matches([string]$link.GpLink, '\{([0-9a-fA-F-]{36})\}')) { $null = $linkedIds.Add($match.Groups[1].Value) }
    }
    $unlinked = @(foreach ($gpo in $gpos) {
            if ([string]::IsNullOrWhiteSpace([string]$gpo.Id)) { throw 'A GPO has no identifier; its links cannot be assessed.' }
            if (-not $linkedIds.Contains(([string]$gpo.Id).Trim('{}'))) { $gpo }
        })
    $details = @(foreach ($gpo in @($unlinked | Sort-Object DisplayName)) {
            [pscustomobject]@{
                Name = $gpo.DisplayName
                Created = if ($null -ne $gpo.CreationTime) { ([datetime]$gpo.CreationTime).ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
                Modified = if ($null -ne $gpo.ModificationTime) { ([datetime]$gpo.ModificationTime).ToString('yyyy-MM-dd HH:mm:ss') } else { $null }
            }
        })
    $pass = $unlinked.Count -eq 0
    $summary = if ($pass) { 'Well done. No unlinked GPOs were found.' } else { "$($unlinked.Count) of $($gpos.Count) GPOs have no links. Review their purpose and archive or remove obsolete policies after verification." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPOs' = $gpos.Count; 'Linked GPOs' = $gpos.Count - $unlinked.Count; 'Unlinked GPOs' = $unlinked.Count }) -Details $details -Properties Name, Created, Modified -Headers GPO, Created, Modified
    Add-MtTestResultDetail -Result $result
    return $pass
}
