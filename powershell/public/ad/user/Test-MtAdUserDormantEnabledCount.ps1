function Test-MtAdUserDormantEnabledCount {
    <#
    .SYNOPSIS
    Counts enabled user accounts that have been dormant for more than 90 days.

    .DESCRIPTION
    This test identifies enabled user accounts whose last recorded logon date is older
    than 90 days. Dormant enabled accounts increase risk because they may be forgotten,
    retain privileges, and become attractive targets for unauthorized access.

    .EXAMPLE
    Test-MtAdUserDormantEnabledCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserDormantEnabledCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserDormantEnabledCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user dormant enabled count"

    $thresholdDays = 90
    $thresholdDate = (Get-Date).AddDays(-$thresholdDays)
    $users = @($adState.Users)
    $enabledUsers = @($users | Where-Object { $_.Enabled -eq $true })
    $dormantUsers = @($enabledUsers | Where-Object {
            $null -ne $_.LastLogonDate -and $_.LastLogonDate -lt $thresholdDate
        })

    $dormantCount = $dormantUsers.Count
    $enabledCount = $enabledUsers.Count
    $totalCount = $users.Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($dormantCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Dormant Enabled Users (>90 days) | $dormantCount |`n"
        $result += "| Dormant Percentage (of enabled) | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $dormantCount out of $enabledCount enabled users ($percentage%) have not logged on in more than $thresholdDays days.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserDormantEnabledCount"

    return $testResult
}


