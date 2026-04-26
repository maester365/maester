<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoVersionMismatchDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs with a version mismatch.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then returns a markdown table listing all GPO reports whose HasVersionMismatch value is true.

    .EXAMPLE
    Test-MtAdGpoVersionMismatchDetails

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes a markdown table of GPOs with version mismatches.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoVersionMismatchDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpoReports = $gpoState.GPOReports
    if ($null -eq $gpoReports) {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory GPO report data from Get-MtADGpoState.'
        return $false
    }

    $gpoReportsArray = @($gpoReports | Where-Object { $null -ne $_ })
    $mismatched = $gpoReportsArray | Where-Object { [bool]$_.HasVersionMismatch }
    $mismatchCount = @($mismatched).Count

    $testResult = $true

    $table = "| GPO Name | HasVersionMismatch |`n"
    $table += '| --- | --- |' + "`n"

    foreach ($report in ($mismatched | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\\|', '\\&#124;'
        $table += "| $name | $([bool]$report.HasVersionMismatch) |`n"
    }

    $recommendation = if ($mismatchCount -gt 0) {
        "GPO version mismatch details were returned ($mismatchCount). Review these GPOs to ensure their versions are consistent."
    } else {
        '✅ No GPO version mismatches were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



