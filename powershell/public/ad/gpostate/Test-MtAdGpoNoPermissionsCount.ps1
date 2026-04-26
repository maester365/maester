function Test-MtAdGpoNoPermissionsCount {
    <#
    .SYNOPSIS
    Counts Group Policy Objects (GPOs) with missing permissions.

    .DESCRIPTION
    This test retrieves GPO state data and counts how many GPO reports indicate that
    permissions are not present.

    .EXAMPLE
    Test-MtAdGpoNoPermissionsCount

    Returns $true when no GPOs are missing permissions, otherwise $false.
    The test result includes a markdown table with the count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoPermissionsCount
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
    $reportsWithNoPermissions = @(
        foreach ($report in $gpoReports) {
            $permissionsPresent = $null
            if ($report.PSObject.Properties.Name -contains 'PermissionsPresent') {
                $permissionsPresent = $report.PermissionsPresent
            }

            if ($permissionsPresent -eq $false -or $null -eq $permissionsPresent) {
                $report
            }
        }
    )

    $noPermissionsCount = ($reportsWithNoPermissions | Measure-Object).Count
    $testResult = $noPermissionsCount -eq 0

    $sampleLimit = 5
    $sampleGpo = $reportsWithNoPermissions | Select-Object -First $sampleLimit
    $sampleNames = @($sampleGpo | ForEach-Object {
        $name = $null
        if ($_.PSObject.Properties.Name -contains 'Name') { $name = $_.Name }
        if ([string]::IsNullOrWhiteSpace($name)) { $name = '' }
        $name
    }) | Where-Object { $_ }
    $sampleNamesText = ($sampleNames -join ', ')
    if ($noPermissionsCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPO Reports | $([int]($gpoReports | Measure-Object).Count) |`n"
    $resultTable += "| GPO Reports With No Permissions | $noPermissionsCount |`n"
    if ($noPermissionsCount -gt 0 -and $sampleNamesText) {
        $resultTable += "| Sample GPO Reports | $sampleNamesText |`n"
    }

    if ($testResult) {
        $recommendation = '✅ No GPO reports were found with missing permissions. Active Directory GPO permissions were analyzed successfully.'
    }
    else {
        $recommendation = "⚠️ GPO reports were found with missing permissions ($noPermissionsCount). Review and remediate GPO security so permissions are correctly applied to required principals."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}

