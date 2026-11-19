function Test-MtAdGpoDisabledLinkCount {
    <#
    .SYNOPSIS
    Counts disabled GPO links and lists their policies and linked containers.
    .DESCRIPTION
    Uses normalized cached link states, including links that are both disabled and enforced.
    .PARAMETER Investigate
    Marks the inventory for investigation instead of reporting a successful read as Passed.
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([switch] $Investigate)

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOLinks -or $null -eq $state.GPOs) {
        throw 'GPO links or GPO metadata could not be collected; cannot inventory disabled links.'
    }
    $links = @($state.GPOLinks | Where-Object { $null -ne $_ })
    if (@($links | Where-Object { $null -eq $_.IsDisabled }).Count -gt 0) {
        throw 'One or more GPO link states could not be evaluated.'
    }
    $disabled = @($links | Where-Object { $true -eq $_.IsDisabled })
    $details = @(foreach ($link in @($disabled | Sort-Object DistinguishedName, GpoGuid)) {
        $gpo = @($state.GPOs | Where-Object { ([string]$_.Id).Trim('{}') -eq ([string]$link.GpoGuid).Trim('{}') } | Select-Object -First 1)
        $name = if ($gpo.Count -gt 0) { [string]$gpo[0].DisplayName } else { [string]$link.GpoGuid }
        [pscustomobject]@{ Name = $name; Container = $link.DistinguishedName }
    })
    $summary = if ($links.Count -eq 0) { 'No GPO links were returned in the collected inventory.' }
    elseif ($disabled.Count -eq 0) { "No disabled GPO links were found. All $($links.Count) collected links are enabled." }
    else { "$($disabled.Count) of $($links.Count) GPO links are disabled. Review whether these disabled links are intentional." }
    if (-not $Investigate -and $disabled.Count -eq 0 -and $links.Count -gt 0) { $summary = "Well done. $summary" }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics ([ordered]@{ 'Total GPO links' = $links.Count; 'Enabled GPO links' = $links.Count - $disabled.Count; 'Disabled GPO links' = $disabled.Count }) -Details $details -Properties Name, Container -Headers GPO, 'Linked container'
    Add-MtTestResultDetail -Result $result -Investigate:$Investigate
    return $true
}
