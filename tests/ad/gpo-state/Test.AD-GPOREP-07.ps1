function Test-MtAdGpoDenyAceCount {
    <#
    .SYNOPSIS
    Checks for GPOs with deny access entries.
    .DESCRIPTION
    Counts deny ACE findings and lists affected GPOs and unreadable permissions.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-07', Title = 'GPOs should not have unintended deny access entries',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Medium', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Platform = 'Windows', Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports) { throw 'GPO permission reports could not be collected.' }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    $found = @($reports | Where-Object { $true -eq $_.HasDenyAce })
    $unknown = @($reports | Where-Object { $null -eq $_.HasDenyAce })
    if ($unknown.Count -eq $reports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read (0 of $($reports.Count) GPOs evaluated)."
        return $null
    }
    $table = "| GPO | Deny ACE |`n| --- | --- |`n"
    foreach ($report in @($found + $unknown | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $status = if ($null -eq $report.HasDenyAce) { 'Not evaluated' } else { 'Present' }
        $table += "| $name | $status |`n"
    }
    $pass = $found.Count -eq 0
    $message = if ($pass -and $unknown.Count -eq 0) { "Well done. No deny ACEs found on $($reports.Count) GPOs." }
    else { "Review deny ACEs on $($found.Count) of $($reports.Count) GPOs; remove unintended entries. Permissions could not be read for $($unknown.Count) GPOs." }
    Add-MtTestResultDetail -Result "$message`n`n$table" -Investigate:($pass -and $unknown.Count -gt 0)
    return $pass
}
