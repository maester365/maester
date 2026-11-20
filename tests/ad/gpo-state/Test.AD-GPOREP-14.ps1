function Test-MtAdGpoEnforcementCount {
    <#
    .SYNOPSIS
    Inventories GPOs that have at least one enforced link.

    .DESCRIPTION
    Counts policies, not link entries. Enforcement overrides Block Inheritance;
    unknown link data remains visible rather than being counted as not enforced.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOREP-14'

    Inventories GPOs with enforced links and unknown enforcement for investigation.

    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-14
    #>
    [MaesterTest(
        Id                 = 'AD-GPOREP-14',
        Title              = 'GPOs with enforced links should be investigated',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'infrastructure',
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
    if ($null -eq $state -or $null -eq $state.GPOs) { throw 'GPO metadata could not be collected; enforcement cannot be inventoried.' }
    $gpos = @($state.GPOs | Where-Object { $null -ne $_ })
    $linksComplete = Test-MtAdGpoLinksComplete -State $state
    # A null aggregate in GPOReports can mean an unlinked GPO, not a failed read.
    # The cached normalized link collection distinguishes known no-links from unknown.
    $rows = @(foreach ($gpo in $gpos) {
            $assessment = 'Unknown'
            if ($null -ne $state.GPOLinks -and -not [string]::IsNullOrWhiteSpace([string]$gpo.Id)) {
                $links = @($state.GPOLinks | Where-Object { ([string]$_.GpoGuid).Trim('{}') -eq ([string]$gpo.Id).Trim('{}') })
                if (@($links | Where-Object { $true -eq $_.IsEnforced }).Count -gt 0) { $assessment = 'Enforced link present' }
                elseif ($linksComplete -and @($links | Where-Object { $null -eq $_.IsEnforced }).Count -eq 0) { $assessment = 'No enforced links' }
            }
            [pscustomobject]@{ Name = $gpo.DisplayName; Enforcement = $assessment }
        })
    $enforced = @($rows | Where-Object Enforcement -EQ 'Enforced link present')
    $unknown = @($rows | Where-Object Enforcement -EQ 'Unknown')
    $details = @($enforced + $unknown | Sort-Object Name)
    $summary = if ($enforced.Count -eq 0 -and $unknown.Count -eq 0) { 'No collected GPO has an enforced link.' }
    elseif ($unknown.Count -eq $gpos.Count) { 'Link enforcement could not be determined for any collected GPO.' }
    elseif ($enforced.Count -eq 0) { 'No enforced links were found among evaluated GPOs.' }
    else { "$($enforced.Count) of $($gpos.Count) GPOs have enforced links. Review their scope and inheritance overrides." }
    if ($unknown.Count -gt 0) { $summary += " Link enforcement is unknown for $($unknown.Count) GPOs." }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPOs' = $gpos.Count; 'GPOs with enforced links' = $enforced.Count; 'GPOs with unknown enforcement' = $unknown.Count }) -Details $details -Properties Name, Enforcement -Headers GPO, 'Link enforcement'
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
