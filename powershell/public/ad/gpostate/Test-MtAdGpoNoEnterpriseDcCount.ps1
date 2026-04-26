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
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = $null
    try {
        $gpoState = Get-MtADGpoState
    }
    catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

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
    $reportsWithNoEnterpriseDc = @(
        foreach ($report in $gpoReports) {
            $hasEnterpriseDomainControllers = $null
            if ($report.PSObject.Properties.Name -contains 'HasEnterpriseDomainControllers') {
                $hasEnterpriseDomainControllers = $report.HasEnterpriseDomainControllers
            }

            if ($hasEnterpriseDomainControllers -eq $false -or $null -eq $hasEnterpriseDomainControllers) {
                $report
            }
        }
    )

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

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |`n"
    $resultTable += "| GPO Reports Without Enterprise Domain Controllers | $noEnterpriseDcCount |`n"
    if ($noEnterpriseDcCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |`n"
    }

    if ($testResult) {
        $recommendation = '✅ No GPO reports were found missing Enterprise Domain Controllers.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found missing Enterprise Domain Controllers ($noEnterpriseDcCount)."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}

