function Test-MtAdGpoNoPermissionsCount {
    <#
    .SYNOPSIS
    Checks whether any GPO has an empty permissions list.
    .DESCRIPTION
    Counts GPOs with no DACL entries and lists affected and unreadable GPOs.
    .EXAMPLE
    Invoke-MtTest -Id AD-GPOREP-01
    Assess GPOs for empty permission lists; review unreadable permissions separately.
    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-01
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-01',
        Title = 'No GPO should have an empty permissions list',
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
    if ($reports.Count -eq 0) { throw 'No GPO permission reports were collected; cannot establish an empty permissions list.' }
    $missing = @($reports | Where-Object { $false -eq $_.PermissionsPresent })
    $unknown = @($reports | Where-Object { $null -eq $_.PermissionsPresent })
    $table = "| GPO | Permissions |`n| --- | --- |`n"
    foreach ($report in @($missing + $unknown | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $status = if ($null -eq $report.PermissionsPresent) { 'Not evaluated' } else { 'Empty' }
        $table += "| $name | $status |`n"
    }
    $pass = $missing.Count -eq 0
    $investigate = $pass -and $unknown.Count -gt 0
    $message = if ($investigate) { "Permissions could not be evaluated for $($unknown.Count) of $($reports.Count) GPOs." }
    elseif ($pass) { "Well done. All $($reports.Count) GPOs have permissions." }
    else { "$($missing.Count) of $($reports.Count) GPOs have no permissions; review their ACLs. $($unknown.Count) could not be evaluated." }
    Add-MtTestResultDetail -Result "$message`n`n$table" -Investigate:$investigate
    return $pass
}
