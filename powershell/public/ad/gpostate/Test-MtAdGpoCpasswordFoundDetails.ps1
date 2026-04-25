<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoCpasswordFoundDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs that contain a cpassword.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then returns a markdown table listing all GPO reports whose CpasswordFound value is true.

    .EXAMPLE
    Test-MtAdGpoCpasswordFoundDetails

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes a markdown table of GPOs with cpassword.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoCpasswordFoundDetails
    #>
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
    $found = $gpoReportsArray | Where-Object { [bool]$_.CpasswordFound }
    $foundCount = @($found).Count

    $testResult = $true

    $table = "| GPO Name | CpasswordFound | DefaultPasswordFound |`n"
    $table += '| --- | --- | --- |' + "`n"

    foreach ($report in ($found | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\\|', '\\&#124;'

        $cpasswordFound = [bool]$report.CpasswordFound
        $defaultPasswordFound = [bool]$report.DefaultPasswordFound
        $table += "| $name | $cpasswordFound | $defaultPasswordFound |`n"
    }

    $recommendation = if ($foundCount -gt 0) {
        "GPO cpassword details were returned ($foundCount). Review these GPOs to ensure Group Policy Preferences passwords are handled securely."
    }
    else {
        '✅ No GPOs with cpassword were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
