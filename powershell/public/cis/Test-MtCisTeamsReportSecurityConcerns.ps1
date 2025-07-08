<#
.SYNOPSIS
    Ensure users can report security concerns in Teams to internal destination

.DESCRIPTION
    Report security concerns in Teams only to internal destination
    CIS Microsoft 365 Foundations Benchmark v5.0.0

.EXAMPLE
    Test-MtCisTeamsReportSecurityConcerns

    Returns true if configured properly

.LINK
    https://maester.dev/docs/commands/Test-MtCisTeamsReportSecurityConcerns
#>
function Test-MtCisTeamsReportSecurityConcerns {
    [CmdletBinding()]
    [OutputType([bool])]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Allow')]
    param()

    if (-not (Test-MtConnection Teams)) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedTeams
        return $null
    }

    Write-Verbose 'Test-MtCisTeamsReportSecurityConcerns: Checking if users can report security concerns in Teams to internal destination'

    try {
        $return = $true
        $MicrosoftTeamsCheck = Get-CsTeamsMessagingPolicy -Identity Global | Select-Object AllowSecurityEndUserReporting
        $MicrosoftReportPolicy = Get-ReportSubmissionPolicy | Select-Object ReportJunkToCustomizedAddress, ReportNotJunkToCustomizedAddress, ReportPhishToCustomizedAddress, ReportJunkAddresses, ReportNotJunkAddresses, ReportPhishAddresses, ReportChatMessageEnabled, ReportChatMessageToCustomizedAddressEnabled

        $passResult = '✅ Pass'
        $failResult = '❌ Fail'

        $result = "| Policy | Value | Status |`n"
        $result += "| --- | --- | --- |`n"

        if ($MicrosoftTeamsCheck.AllowSecurityEndUserReporting -eq $false) {
            $result += "| AllowSecurityEndUserReporting | $($MicrosoftTeamsCheck.AllowSecurityEndUserReporting) | $failResult |`n"
            $return = $false
        } else {
            $result += "| AllowSecurityEndUserReporting | $($MicrosoftTeamsCheck.AllowSecurityEndUserReporting) | $passResult |`n"
        }
        if ($MicrosoftReportPolicy.ReportJunkToCustomizedAddress -eq $false) {
            $result += "| ReportJunkToCustomizedAddress | $($MicrosoftReportPolicy.ReportJunkToCustomizedAddress) | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportJunkToCustomizedAddress | $($MicrosoftReportPolicy.ReportJunkToCustomizedAddress) | $passResult |`n"
        }

        if ($MicrosoftReportPolicy.ReportNotJunkToCustomizedAddress -eq $false) {
            $result += "| ReportNotJunkToCustomizedAddress | $($MicrosoftReportPolicy.ReportNotJunkToCustomizedAddress) | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportNotJunkToCustomizedAddress | $($MicrosoftReportPolicy.ReportNotJunkToCustomizedAddress) | $passResult |`n"
        }
        if ($MicrosoftReportPolicy.ReportPhishToCustomizedAddress -eq $false) {
            $result += "| ReportPhishToCustomizedAddress | $($MicrosoftReportPolicy.ReportPhishToCustomizedAddress) | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportPhishToCustomizedAddress | $($MicrosoftReportPolicy.ReportPhishToCustomizedAddress) | $passResult |`n"
        }
        if ([string]::IsNullOrEmpty($MicrosoftReportPolicy.ReportJunkAddresses)) {
            $result += "| ReportJunkAddresses | NULL | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportJunkAddresses | $($MicrosoftReportPolicy.ReportJunkAddresses) | $passResult |`n"
        }
        if ([string]::IsNullOrEmpty($MicrosoftReportPolicy.ReportNotJunkAddresses)) {
            $result += "| ReportNotJunkAddresses | NULL | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportNotJunkAddresses | $($MicrosoftReportPolicy.ReportNotJunkAddresses) | $passResult |`n"
        }
        if ([string]::IsNullOrEmpty($MicrosoftReportPolicy.ReportPhishAddresses)) {
            $result += "| ReportPhishAddresses | NULL | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportPhishAddresses | $($MicrosoftReportPolicy.ReportPhishAddresses) | $passResult |`n"
        }
        if ($MicrosoftReportPolicy.ReportChatMessageEnabled -eq $true) {
            $result += "| ReportChatMessageEnabled | $($MicrosoftReportPolicy.ReportChatMessageEnabled) | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportChatMessageEnabled | $($MicrosoftReportPolicy.ReportChatMessageEnabled) | $passResult |`n"
        }
        if ($MicrosoftReportPolicy.ReportChatMessageToCustomizedAddressEnabled -eq $false) {
            $result += "| ReportChatMessageToCustomizedAddressEnabled | $($MicrosoftReportPolicy.ReportChatMessageToCustomizedAddressEnabled) | $failResult |`n"
            $return = $false
        } else {
            $result += "| ReportChatMessageToCustomizedAddressEnabled | $($MicrosoftReportPolicy.ReportChatMessageToCustomizedAddressEnabled) | $passResult |`n"
        }
        if ($return) {
            $testResultMarkdown = "Well done. All report submission policies are configured properly.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "All or specific report submission policies are missing proper configuration.`n`n%TestResult%"
        }

        $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
        Add-MtTestResultDetail -Result $testResultMarkdown
        return $return
    } catch {
        Add-MtTestResultDetail -SkippedBecause Error -SkippedError $_
        return $null
    }
}
