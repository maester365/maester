function Test-MtAdGpoNoPermissionsCount {
    <#
    .SYNOPSIS
    Checks whether any GPO has an empty permissions list.
    .DESCRIPTION
    Counts GPOs with no DACL entries and lists affected and unreadable GPOs.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-01', Title = 'No GPO should have an empty permissions list',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Medium', UserImpact = 'Low',
        ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports) { throw 'GPO permission reports could not be collected.' }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    $missing = @($reports | Where-Object { $false -eq $_.PermissionsPresent })
    $unknown = @($reports | Where-Object { $null -eq $_.PermissionsPresent })
    if ($unknown.Count -eq $reports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read (0 of $($reports.Count) GPOs evaluated)."
        return $null
    }
    $table = "| GPO | Permissions |`n| --- | --- |`n"
    foreach ($report in @($missing + $unknown | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $status = if ($null -eq $report.PermissionsPresent) { 'Not evaluated' } else { 'Empty' }
        $table += "| $name | $status |`n"
    }
    $pass = $missing.Count -eq 0
    $investigate = $pass -and $unknown.Count -gt 0
    $message = if ($investigate) { "Permissions could not be read for $($unknown.Count) of $($reports.Count) GPOs." }
    elseif ($pass) { "Well done. All $($reports.Count) GPOs have permissions." }
    else { "$($missing.Count) of $($reports.Count) GPOs have no permissions; review their ACLs. Permissions could not be read for $($unknown.Count) GPOs." }
    Add-MtTestResultDetail -Result "$message`n`n$table" -Investigate:$investigate
    return $pass
}
