function Test-MtAdGpoNoEnterpriseDcCount {
    <#
    .SYNOPSIS
    Counts GPO reports that do not include Enterprise Domain Controllers.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    Enterprise Domain Controllers are not present.

    .EXAMPLE
    Test-MtAdGpoNoEnterpriseDcCount

    Returns $true when no GPO reports are missing Enterprise Domain Controllers, otherwise $false.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoEnterpriseDcCount
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-05',
        Title = 'GPOs without enterprise domain controllers count should be retrievable',
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

    Write-Verbose "Starting Test-MtAdGpoNoEnterpriseDcCount"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no enterprise dc count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # HasEnterpriseDomainControllers is $null when the security descriptor of a GPO could not be read: unknown, not missing.
    $reportsWithNoEnterpriseDc = @($gpoReports | Where-Object { $false -eq $_.HasEnterpriseDomainControllers })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.HasEnterpriseDomainControllers })
    $notEvaluatedCount = $reportsNotEvaluated.Count

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $noEnterpriseDcCount = ($reportsWithNoEnterpriseDc | Measure-Object).Count
    $testResult = $noEnterpriseDcCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithNoEnterpriseDc | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($noEnterpriseDcCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |" + "`n"
    $resultTable += "| --- | --- |" + "`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |" + "`n"
    $resultTable += "| GPO Reports Without Enterprise Domain Controllers | $noEnterpriseDcCount |" + "`n"
    if ($noEnterpriseDcCount -gt 0 -and $sampleNamesText) {
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
        $recommendation = "ℹ️ No GPO reports were found missing Enterprise Domain Controllers among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    }
    elseif ($testResult) {
        $recommendation = '✅ No GPO reports were found missing Enterprise Domain Controllers.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found missing Enterprise Domain Controllers ($noEnterpriseDcCount)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoEnterpriseDcCount"
    return $testResult
}
