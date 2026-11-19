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
    $table = "| Metric | Value |`n| --- | --- |`n| Total Links | $($links.Count) |`n| Disabled Links | $($disabled.Count) |`n"
    $table += "`n| GPO | Linked container |`n| --- | --- |`n"
    foreach ($link in @($disabled | Sort-Object DistinguishedName, GpoGuid)) {
        $gpo = @($state.GPOs | Where-Object { ([string]$_.Id).Trim('{}') -eq ([string]$link.GpoGuid).Trim('{}') } | Select-Object -First 1)
        $name = if ($gpo.Count -gt 0) { [string]$gpo[0].DisplayName } else { [string]$link.GpoGuid }
        $name = [System.Net.WebUtility]::HtmlEncode($name) -replace '\|', '&#124;'
        $container = [System.Net.WebUtility]::HtmlEncode([string]$link.DistinguishedName) -replace '\|', '&#124;'
        $table += "| $name | $container |`n"
    }
    Add-MtTestResultDetail -Result "Review $($disabled.Count) disabled links among $($links.Count) GPO links; some may be intentionally disabled.`n`n$table" -Investigate:$Investigate
    return $true
}
