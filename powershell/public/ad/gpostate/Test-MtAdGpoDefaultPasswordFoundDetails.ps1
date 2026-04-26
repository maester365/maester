<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoDefaultPasswordFoundDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs that contain a default password.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then returns a markdown table listing all GPO reports whose DefaultPasswordFound value is true.

    .EXAMPLE
    Test-MtAdGpoDefaultPasswordFoundDetails

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes a markdown table of GPOs with a default password.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDefaultPasswordFoundDetails
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
    $found = $gpoReportsArray | Where-Object { [bool]$_.DefaultPasswordFound }
    $foundCount = @($found).Count

    $testResult = $true

    $table = "| GPO Name | DefaultPasswordFound | CpasswordFound |`n"
    $table += '| --- | --- | --- |' + "`n"

    foreach ($report in ($found | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\\|', '\\&#124;'

        $defaultPasswordFound = [bool]$report.DefaultPasswordFound
        $cpasswordFound = [bool]$report.CpasswordFound
        $table += "| $name | $defaultPasswordFound | $cpasswordFound |`n"
    }

    $recommendation = if ($foundCount -gt 0) {
        "GPO default password details were returned ($foundCount). Review these GPOs to ensure Group Policy Preferences passwords are handled securely."
    }
    else {
        '✅ No GPOs with default password were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



