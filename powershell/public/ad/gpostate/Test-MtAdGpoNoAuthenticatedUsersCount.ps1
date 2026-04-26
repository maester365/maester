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
    $reportsWithNoAuthenticatedUsers = @(
        foreach ($report in $gpoReports) {
            $hasAuthenticatedUsers = $null
            if ($report.PSObject.Properties.Name -contains 'HasAuthenticatedUsers') {
                $hasAuthenticatedUsers = $report.HasAuthenticatedUsers
            }

            if ($hasAuthenticatedUsers -eq $false -or $null -eq $hasAuthenticatedUsers) {
                $report
            }
        }
    )

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

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |`n"
    $resultTable += "| GPO Reports Without Authenticated Users | $noAuthenticatedUsersCount |`n"
    if ($noAuthenticatedUsersCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |`n"
    }

    if ($testResult) {
        $recommendation = '✅ No GPO reports were found missing Authenticated Users. GPO permissions were analyzed successfully.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found missing Authenticated Users ($noAuthenticatedUsersCount). Review and remediate GPO security ACLs."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



