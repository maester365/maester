function Test-MtAdGpoNoAuthenticatedUsersCount {
    <#
    .SYNOPSIS
    Checks GPO permissions for Authenticated Users.
    .DESCRIPTION
    Lists GPOs without an Authenticated Users allow entry and those with unreadable permissions.
    .EXAMPLE
    Invoke-MtTest -Id AD-GPOREP-03
    Assess Authenticated Users allow entries; review unreadable GPOs separately.
    .LINK
    https://maester.dev/docs/tests/AD-GPOREP-03
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-03',
        Title = 'GPOs should permit Authenticated Users where required',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'access-control',
        ResourceType = 'GroupPolicy',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.GPOReports) { throw 'GPO permission reports could not be collected.' }
    $reports = @($state.GPOReports | Where-Object { $null -ne $_ })
    if ($reports.Count -eq 0) { throw 'No GPO permission reports were collected.' }
    $missing = @($reports | Where-Object { $false -eq $_.HasAuthenticatedUsers })
    $unknown = @($reports | Where-Object { $null -eq $_.HasAuthenticatedUsers })
    $table = "| GPO | Authenticated Users access |`n| --- | --- |`n"
    foreach ($report in @($missing + $unknown | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $status = if ($null -eq $report.HasAuthenticatedUsers) { 'Not evaluated' } else { 'No allow entry' }
        $table += "| $name | $status |`n"
    }
    Add-MtTestResultDetail -Result "Review Authenticated Users permissions for $($missing.Count) of $($reports.Count) GPOs; $($unknown.Count) could not be evaluated. An alternative security-filtering group may be intentional.`n`n$table" -Investigate
    return $true
}
