function Test-MtAdUserSidHistoryCount {
    <#
    .SYNOPSIS
    Counts users with SID History set in Active Directory.

    .DESCRIPTION
    This test identifies user objects that have the SIDHistory attribute populated.
    SID History is typically used during migrations to preserve access to resources.
    Persistent SID History can represent legacy migration artifacts or access paths
    that should be reviewed for least privilege and trust boundary concerns.

    .EXAMPLE
    Test-MtAdUserSidHistoryCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with SID History.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserSidHistoryCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserSidHistoryCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user sid history count"

    $users = $adState.Users
    $usersWithSidHistory = $users | Where-Object {
        $_.SIDHistory -and
        ($_.SIDHistory | Measure-Object).Count -gt 0
    }

    $sidHistoryCount = ($usersWithSidHistory | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($sidHistoryCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with SID History | $sidHistoryCount |`n"
        $result += "| SID History Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory users have been analyzed. $sidHistoryCount out of $totalCount users ($percentage%) have SID History set.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserSidHistoryCount"

    return $testResult
}


