<# <!-- OMO_INTERNAL_INITIATOR --> #>
function Test-MtAdGpoDisabledLinkDetails {
    <#
    .SYNOPSIS
    Returns details of GPOs with disabled GPO links.

    .DESCRIPTION
    This test retrieves Active Directory Group Policy state information using Get-MtADGpoState,
    then returns a markdown table listing all GPO reports whose DisabledLinks value is greater than 0.

    .EXAMPLE
    Test-MtAdGpoDisabledLinkDetails

    Returns $true if GPO report data is accessible, $false otherwise.
    The test result includes a markdown table of GPOs with disabled link(s).

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDisabledLinkDetails
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
    $disabled = $gpoReportsArray | Where-Object { [int]$_.DisabledLinks -gt 0 }
    $disabledCount = @($disabled).Count

    $testResult = $true

    $table = "| GPO Name | DisabledLinks | Enforcement |`n"
    $table += '| --- | --- | --- |' + "`n"

    foreach ($report in ($disabled | Sort-Object -Property Name)) {
        $name = [string]$report.Name
        $name = $name -replace '\\|', '\\&#124;'

        $disabledLinks = [int]$report.DisabledLinks
        $enforcement = [int]$report.Enforcement
        $table += "| $name | $disabledLinks | $enforcement |`n"
    }

    $recommendation = if ($disabledCount -gt 0) {
        "GPO disabled link details were returned ($disabledCount). Review these GPO links to ensure they are still intended."
    }
    else {
        '✅ No GPOs with disabled link configuration were found.'
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $table

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
