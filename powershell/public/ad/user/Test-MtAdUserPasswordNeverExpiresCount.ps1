function Test-MtAdUserPasswordNeverExpiresCount {
    <#
    .SYNOPSIS
    Counts enabled user accounts with passwords set to never expire.

    .DESCRIPTION
    This test identifies enabled user accounts where password expiration has been
    disabled. Non-expiring passwords can weaken password hygiene and are often used for
    legacy or service accounts that require stronger compensating controls.

    .EXAMPLE
    Test-MtAdUserPasswordNeverExpiresCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserPasswordNeverExpiresCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserPasswordNeverExpiresCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user password never expires count"

    $users = @($adState.Users)
    $enabledUsers = @($users | Where-Object { $_.Enabled -eq $true })
    $nonExpiringUsers = @($enabledUsers | Where-Object { $_.PasswordNeverExpires -eq $true })

    $nonExpiringCount = $nonExpiringUsers.Count
    $enabledCount = $enabledUsers.Count
    $totalCount = $users.Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($nonExpiringCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Enabled Users with Password Never Expires | $nonExpiringCount |`n"
        $result += "| Non-Expiring Percentage (of enabled) | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $nonExpiringCount out of $enabledCount enabled users ($percentage%) have non-expiring passwords.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserPasswordNeverExpiresCount"

    return $testResult
}


