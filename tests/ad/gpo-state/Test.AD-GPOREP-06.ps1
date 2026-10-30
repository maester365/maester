function Test-MtAdGpoNoDomainComputersCount {
    <#
    .SYNOPSIS
    Counts GPO reports that include neither Domain Computers nor Authenticated Users.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    Domain Computers are not present. A GPO without Domain Computers is only a finding
    when Authenticated Users is not present either (MS16-072).

    .EXAMPLE
    Test-MtAdGpoNoDomainComputersCount

    Returns $true when no GPO reports are missing both Domain Computers and Authenticated Users, otherwise $false.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoDomainComputersCount
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-06',
        Title = 'GPOs without domain computers count should be retrievable',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'access-control',
        ResourceType = 'GroupPolicy',
        Severity = 'Low',
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

    Write-Verbose "Starting Test-MtAdGpoNoDomainComputersCount"
    $gpoState = $null
    $gpoState = Get-MtADGpoState
Write-Verbose "Retrieved AD state"

if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no domain computers count"

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports | Where-Object { $null -ne $_ })
    # HasDomainComputers is $null when the security descriptor of a GPO could not be read: unknown, not missing.
    $reportsWithNoDomainComputers = @($gpoReports | Where-Object { $false -eq $_.HasDomainComputers })
    $reportsNotEvaluated = @($gpoReports | Where-Object { $null -eq $_.HasDomainComputers })
    $notEvaluatedCount = $reportsNotEvaluated.Count
    # The default GPO permissions hold Authenticated Users and no Domain Computers entry, so a missing Domain
    # Computers entry is only a finding when Authenticated Users is missing as well (MS16-072).
    $reportsWithNoComputerAccess = @($reportsWithNoDomainComputers | Where-Object { $false -eq $_.HasAuthenticatedUsers })

    if ($notEvaluatedCount -eq $gpoReports.Count) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "GPO permissions could not be read from Active Directory (0 of $($gpoReports.Count) GPOs evaluated), so this test could not be evaluated."
        return $null
    }

    $noDomainComputersCount = ($reportsWithNoDomainComputers | Measure-Object).Count
    $noComputerAccessCount = ($reportsWithNoComputerAccess | Measure-Object).Count
    $testResult = $noComputerAccessCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithNoComputerAccess | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($noComputerAccessCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |" + "`n"
    $resultTable += "| --- | --- |" + "`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |" + "`n"
    $resultTable += "| GPO Reports Without Domain Computers | $noDomainComputersCount |" + "`n"
    $resultTable += "| GPO Reports Without Domain Computers And Without Authenticated Users | $noComputerAccessCount |" + "`n"
    if ($noComputerAccessCount -gt 0 -and $sampleNamesText) {
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
        $recommendation = "ℹ️ No GPO reports were found missing both Domain Computers and Authenticated Users among the GPOs that could be evaluated, but the permissions of $notEvaluatedCount GPO(s) could not be read. Review those GPOs manually."
    }
    elseif ($testResult) {
        $recommendation = '✅ No GPO reports were found missing both Domain Computers and Authenticated Users. A GPO without Domain Computers is expected when Authenticated Users has access: the default GPO permissions have no Domain Computers entry.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found missing both Domain Computers and Authenticated Users ($noComputerAccessCount). Computer accounts may be unable to read these GPOs (MS16-072)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:$needsInvestigation
    Write-Verbose "Completed Test-MtAdGpoNoDomainComputersCount"
    return $testResult
}
