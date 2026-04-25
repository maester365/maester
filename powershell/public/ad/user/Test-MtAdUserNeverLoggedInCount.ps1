function Test-MtAdUserNeverLoggedInCount {
    <#
    .SYNOPSIS
    Counts enabled user accounts that have never logged on.

    .DESCRIPTION
    This test identifies enabled user accounts with no recorded last logon date. These
    accounts can indicate incomplete provisioning, abandoned onboarding, or dormant
    accounts that were never validated or used.

    .EXAMPLE
    Test-MtAdUserNeverLoggedInCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserNeverLoggedInCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }

    $users = @($adState.Users)
    $enabledUsers = @($users | Where-Object { $_.Enabled -eq $true })
    $neverLoggedInUsers = @($enabledUsers | Where-Object { $null -eq $_.LastLogonDate })

    $neverLoggedInCount = $neverLoggedInUsers.Count
    $enabledCount = $enabledUsers.Count
    $totalCount = $users.Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($neverLoggedInCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Enabled Users Never Logged In | $neverLoggedInCount |`n"
        $result += "| Never Logged In Percentage (of enabled) | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $neverLoggedInCount out of $enabledCount enabled users ($percentage%) have never logged on.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
