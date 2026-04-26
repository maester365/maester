function Test-MtAdGpoNoPermissionsDetails {
    <#
    .SYNOPSIS
    Returns details of GPO reports missing permissions.

    .DESCRIPTION
    This test retrieves GPO state data and returns a markdown table listing the GPO
    reports where permissions are not present.

    .EXAMPLE
    Test-MtAdGpoNoPermissionsDetails

    Returns $true when no GPOs are missing permissions, otherwise $false.
    The test result includes a markdown table with the affected GPO report names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoNoPermissionsDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoNoPermissionsDetails"
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
    Write-Verbose "Filtering/counting gpo no permissions details"

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

    $table = "| GPO Name | PermissionsPresent |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in @($reportsWithNoPermissions | Sort-Object Name)) {
        $name = if ($null -ne $report.Name) { [string]$report.Name } else { '' }
        $name = $name -replace '\|', '\\&#124;'

        $permissionsPresent = $report.PermissionsPresent
        if ($null -eq $permissionsPresent) { $permissionsPresent = '' }
        $table += "| $name | $permissionsPresent |`n"
    }

    $recommendation = if ($testResult) {
        '✅ No GPO reports were found with missing permissions.'
    }
    else {
        "⚠️ GPO reports were found with missing permissions ($noPermissionsCount)."
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdGpoNoPermissionsDetails"
    return $testResult
}



