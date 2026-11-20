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
    $linksComplete = Test-MtAdGpoLinksComplete -State $state
    $gpoIndex = [System.Collections.Generic.Dictionary[string, object]]::new([StringComparer]::OrdinalIgnoreCase)
    foreach ($gpo in @($state.GPOs | Where-Object { $null -ne $_ })) {
        $id = ([string]$gpo.Id).Trim('{}')
        if (-not [string]::IsNullOrWhiteSpace($id) -and -not $gpoIndex.ContainsKey($id)) { $gpoIndex.Add($id, $gpo) }
    }
    $details = @(foreach ($link in @($disabled | Sort-Object DistinguishedName, GpoGuid)) {
        $id = ([string]$link.GpoGuid).Trim('{}')
        $name = if ($gpoIndex.ContainsKey($id)) { [string]$gpoIndex[$id].DisplayName } else { [string]$link.GpoGuid }
        [pscustomobject]@{ Name = $name; Container = $link.DistinguishedName }
    })
    $summary = if ($links.Count -eq 0) { 'No GPO links were returned in the collected inventory.' }
    elseif ($disabled.Count -eq 0) { "No disabled GPO links were found. All $($links.Count) collected links are enabled." }
    else { "$($disabled.Count) of $($links.Count) GPO links are disabled. Review whether these disabled links are intentional." }
    if (-not $linksComplete) { $summary = "Partial link inventory: $($disabled.Count) known disabled links among $($links.Count) parsed links. Additional links could not be parsed; zero findings would not prove that all links are enabled." }
    elseif (-not $Investigate -and $disabled.Count -eq 0 -and $links.Count -gt 0) { $summary = "Well done. $summary" }
    $metrics = if ($linksComplete) { [ordered]@{ 'Total GPO links' = $links.Count; 'Enabled GPO links' = $links.Count - $disabled.Count; 'Disabled GPO links' = $disabled.Count } }
    else { [ordered]@{ 'Parsed GPO links' = $links.Count; 'Known enabled GPO links' = $links.Count - $disabled.Count; 'Known disabled GPO links' = $disabled.Count; 'Link collection complete' = $false } }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics $metrics -Details $details -Properties Name, Container -Headers GPO, 'Linked container'
    Add-MtTestResultDetail -Result $result -Investigate:($Investigate -or -not $linksComplete)
    return $true
}
