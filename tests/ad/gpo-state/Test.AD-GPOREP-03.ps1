function Test-MtAdGpoNoAuthenticatedUsersCount {
    <#
    .SYNOPSIS
    Counts GPO reports that do not include Authenticated Users.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    Authenticated Users are not present.

    .EXAMPLE
    Test-MtAdGpoNoAuthenticatedUsersCount

    Returns $true when no GPO reports are missing Authenticated Users, otherwise $false.
    The test result includes a markdown table with the count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoAuthenticatedUsersCount
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-03',
        Title = 'GPOs should include Authenticated Users permissions',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'access-control',
        ResourceType = 'GroupPolicy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState -or $null -eq $gpoState.GPOReports) {
        throw 'GPO permission reports could not be collected.'
    }

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # HasAuthenticatedUsers is $null when the security descriptor of a GPO could not be read: unknown, not missing.
    $reportsWithNoAuthenticatedUsers = @($gpoReports | Where-Object { $false -eq $_.HasAuthenticatedUsers })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.HasAuthenticatedUsers })
    $notEvaluatedCount = $reportsNotEvaluated.Count

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $noAuthenticatedUsersCount = ($reportsWithNoAuthenticatedUsers | Measure-Object).Count
    $testResult = $noAuthenticatedUsersCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithNoAuthenticatedUsers | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($noAuthenticatedUsersCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |" + "`n"
    $resultTable += "| --- | --- |" + "`n"
    $resultTable += "| Total GPOs | $($gpoReports.Count) |" + "`n"
    $resultTable += "| GPOs Without Authenticated Users | $noAuthenticatedUsersCount |" + "`n"
    if ($noAuthenticatedUsersCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPOs | $($sampleNamesText.Replace('|', '&#124;')) |" + "`n"
    }
    if ($notEvaluatedCount -gt 0) {
        $notEvaluatedNames = @($reportsNotEvaluated | Select-Object -First $sampleLimit | ForEach-Object { [string]$_.Name }) -join ', '
        $resultTable += "| GPOs Not Evaluated (permissions could not be read) | $notEvaluatedCount |" + "`n"
        $resultTable += "| Sample GPOs Not Evaluated | $($notEvaluatedNames.Replace('|', '&#124;')) |" + "`n"
    }

    $resultTable += "`n| GPO | Authenticated Users permission |`n| --- | --- |`n"
    foreach ($report in @($reportsWithNoAuthenticatedUsers + $reportsNotEvaluated | Sort-Object Name)) {
        $name = [System.Net.WebUtility]::HtmlEncode([string]$report.Name) -replace '\|', '&#124;'
        $status = if ($null -eq $report.HasAuthenticatedUsers) { 'Not evaluated' } else { 'Not present' }
        $resultTable += "| $name | $status |`n"
    }

    # Nothing was flagged, but a GPO whose permissions could not be read is not a pass.
    $needsInvestigation = $testResult -and $notEvaluatedCount -gt 0
    if ($needsInvestigation) {
        $recommendation = "No evaluated GPOs lack Authenticated Users permissions, but permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    }
    elseif ($testResult) {
        $recommendation = 'Well done. No GPOs were found missing Authenticated Users permissions.'
    }
    else {
        $recommendation = "$noAuthenticatedUsersCount GPOs lack Authenticated Users permissions. Review intended security filtering and remediate GPO security ACLs."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoAuthenticatedUsersCount"
    return $testResult
}
