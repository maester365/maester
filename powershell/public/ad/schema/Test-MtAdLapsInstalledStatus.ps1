function Test-MtAdLapsInstalledStatus {
    <#
    .SYNOPSIS
    Checks whether Local Administrator Password Solution (LAPS) is installed in Active Directory.

    .DESCRIPTION
    This test checks if the Local Administrator Password Solution (LAPS) schema extensions
    are present in Active Directory. LAPS is a Microsoft solution that manages local
    administrator passwords on domain-joined computers, storing them securely in AD
    and automatically rotating them on a scheduled basis.

    .EXAMPLE
    Test-MtAdLapsInstalledStatus

    Returns $true if LAPS is installed, $false if not installed or unable to determine.
    The test result includes LAPS installation status.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdLapsInstalledStatus
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    # Check LAPS installation status
    $lapsInstalled = $adState.LapsInstalled

    # Test passes if LAPS is installed (compliance test)
    $testResult = $lapsInstalled -eq $true

    # Generate markdown results
    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| LAPS Installed | $(if ($lapsInstalled) { "Yes" } else { "No" }) |`n"
    $result += "| Status | $(if ($lapsInstalled) { "✅ Compliant" } else { "❌ Not Installed" }) |`n`n"

    if ($lapsInstalled) {
        $result += "**LAPS Schema Attributes:**`n`n"
        $result += "The following LAPS attributes are present in the schema:`n`n"
        $result += "| Attribute | Description |`n"
        $result += "| --- | --- |`n"
        $result += "| ms-Mcs-AdmPwd | Stores the local administrator password |`n"
        $result += "| ms-Mcs-AdmPwdExpirationTime | Stores the password expiration timestamp |`n"

        $testResultMarkdown = "✅ Local Administrator Password Solution (LAPS) is installed and configured in Active Directory. Local administrator passwords are being managed and rotated automatically.`n`n%TestResult%"
    } else {
        $result += "**Recommendation:**`n`n"
        $result += "LAPS is not installed. Consider deploying LAPS to improve security by:`n"
        $result += "- Automatically rotating local administrator passwords`n"
        $result += "- Storing passwords securely in Active Directory`n"
        $result += "- Preventing lateral movement using shared local credentials`n`n"
        $result += "Download LAPS from: https://www.microsoft.com/download/details.aspx?id=46899"

        $testResultMarkdown = "❌ Local Administrator Password Solution (LAPS) is not installed. Local administrator passwords may be shared across multiple systems, creating a security risk.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



