function Test-MtAdGpoNoDomainComputersCount {
    <#
    .SYNOPSIS
    Counts GPO reports that do not include Domain Computers.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    Domain Computers are not present.

    .EXAMPLE
    Test-MtAdGpoNoDomainComputersCount

    Returns $true when no GPO reports are missing Domain Computers, otherwise $false.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoDomainComputersCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoNoDomainComputersCount"
    $gpoState = $null
    try {
        $gpoState = Get-MtADGpoState
    Write-Verbose "Retrieved AD state"
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting gpo no domain computers count"

    $gpoReports = $null
    if ($gpoState.PSObject.Properties.Name -contains 'GPOReports') {
        $gpoReports = $gpoState.GPOReports
    }
    elseif ($gpoState.PSObject.Properties.Name -contains 'GpoReports') {
        $gpoReports = $gpoState.GpoReports
    }
    else {
        $gpoReports = @()
        foreach ($gpo in @($gpoState.GPOs)) {
            foreach ($prop in @('GpoReports', 'GPOReports', 'GpoReport', 'GPOReport')) {
                if ($gpo.PSObject.Properties.Name -contains $prop -and $null -ne $gpo.$prop) {
                    $value = $gpo.$prop
                    if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                        $gpoReports += @($value)
                    }
                    else {
                        $gpoReports += $value
                    }
                }
            }
        }
    }

    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve GPO reports from Get-MtADGpoState.'
        return $false
    }

    $gpoReports = @($gpoReports)
    $reportsWithNoDomainComputers = @(
        foreach ($report in $gpoReports) {
            $hasDomainComputers = $null
            if ($report.PSObject.Properties.Name -contains 'HasDomainComputers') {
                $hasDomainComputers = $report.HasDomainComputers
            }

            if ($hasDomainComputers -eq $false -or $null -eq $hasDomainComputers) {
                $report
            }
        }
    )

    $noDomainComputersCount = ($reportsWithNoDomainComputers | Measure-Object).Count
    $testResult = $noDomainComputersCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithNoDomainComputers | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($noDomainComputersCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |`n"
    $resultTable += "| GPO Reports Without Domain Computers | $noDomainComputersCount |`n"
    if ($noDomainComputersCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |`n"
    }

    if ($testResult) {
        $recommendation = '✅ No GPO reports were found missing Domain Computers.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found missing Domain Computers ($noDomainComputersCount)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoNoDomainComputersCount"
    return $testResult
}



