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
        Title = 'GPOs without authenticated users count should be retrievable',
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

    Write-Verbose "Starting Test-MtAdGpoNoAuthenticatedUsersCount"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no authenticated users count"

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
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |" + "`n"
    $resultTable += "| GPO Reports Without Authenticated Users | $noAuthenticatedUsersCount |" + "`n"
    if ($noAuthenticatedUsersCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |" + "`n"
    }
    if ($notEvaluatedCount -gt 0) {
        $notEvaluatedNames = @($reportsNotEvaluated | Select-Object -First $sampleLimit | ForEach-Object { [string]$_.Name }) -join ', '
        $resultTable += "| GPO Reports Not Evaluated (permissions could not be read) | $notEvaluatedCount |" + "`n"
        $resultTable += "| Sample GPO Reports Not Evaluated | $notEvaluatedNames |" + "`n"
    }

    # Nothing was flagged, but a GPO whose permissions could not be read is not a pass.
    $needsInvestigation = $testResult -and $notEvaluatedCount -gt 0
    if ($needsInvestigation) {
        $recommendation = "ℹ️ No GPO reports were found missing Authenticated Users among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    }
    elseif ($testResult) {
        $recommendation = '✅ No GPO reports were found missing Authenticated Users. GPO permissions were analyzed successfully.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found missing Authenticated Users ($noAuthenticatedUsersCount). Review and remediate GPO security ACLs."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoAuthenticatedUsersCount"
    return $testResult
}
