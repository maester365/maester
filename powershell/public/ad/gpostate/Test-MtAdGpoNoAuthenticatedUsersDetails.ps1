function Test-MtAdGpoNoAuthenticatedUsersDetails {
    <#
    .SYNOPSIS
    Returns details of GPO reports without Authenticated Users.

    .DESCRIPTION
    This test retrieves GPO state data and returns a markdown table listing the GPO
    reports where Authenticated Users are not present.

    .EXAMPLE
    Test-MtAdGpoNoAuthenticatedUsersDetails

    Returns $true when no GPO reports are missing Authenticated Users, otherwise $false.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoAuthenticatedUsersDetails
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

    $table = "| GPO Name | HasAuthenticatedUsers |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in @($reportsWithNoAuthenticatedUsers | Sort-Object Name)) {
        $name = if ($null -ne $report.Name) { [string]$report.Name } else { '' }
        $name = $name -replace '\|', '\\&#124;'

        $hasAuthenticatedUsers = $report.HasAuthenticatedUsers
        if ($null -eq $hasAuthenticatedUsers) { $hasAuthenticatedUsers = '' }
        $table += "| $name | $hasAuthenticatedUsers |`n"
    }

    $recommendation = if ($testResult) {
        '✅ No GPO reports were found missing Authenticated Users.'
    }
    else {
        "⚠️ GPO reports were found missing Authenticated Users ($noAuthenticatedUsersCount)."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
