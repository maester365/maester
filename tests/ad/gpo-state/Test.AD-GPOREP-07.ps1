function Test-MtAdGpoDenyAceCount {
    <#
    .SYNOPSIS
    Inventories GPOs with explicit deny entries.
    .DESCRIPTION
    Lists deny ACE findings for review; deny entries can be intentional.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-07', Title = 'Review GPOs with deny access entries',
        Product = 'ad', Feature = 'group-policy', Area = 'access-control',
        ResourceType = 'GroupPolicy', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
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
    $found = @($reports | Where-Object { $true -eq $_.HasDenyAce })
    $unknown = @($reports | Where-Object { $null -eq $_.HasDenyAce })
    $table = "| GPO | Deny ACE |`n| --- | --- |`n"
    foreach ($report in @($found + $unknown | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $status = if ($null -eq $report.HasDenyAce) { 'Not evaluated' } else { 'Present' }
        $table += "| $name | $status |`n"
    }
    Add-MtTestResultDetail -Result "Review deny ACEs on $($found.Count) of $($reports.Count) GPOs; $($unknown.Count) could not be evaluated.`n`n$table" -Investigate
    return $true
}
