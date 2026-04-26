function Test-MtAdUserAdminCountCount {
    <#
    .SYNOPSIS
    Counts users with AdminCount set in Active Directory.

    .DESCRIPTION
    This test identifies user objects that have the AdminCount attribute set to 1.
    AdminCount is commonly applied to privileged or protected accounts that inherit
    AdminSDHolder protection. These accounts warrant additional review because they
    often retain elevated rights or have previously held privileged memberships.

    .EXAMPLE
    Test-MtAdUserAdminCountCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with AdminCount set.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserAdminCountCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserAdminCountCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user admin count count"

    $users = $adState.Users
    $usersWithAdminCount = $users | Where-Object {
        $_.AdminCount -eq 1
    }

    $adminCount = ($usersWithAdminCount | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($adminCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with AdminCount = 1 | $adminCount |`n"
        $result += "| AdminCount Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory users have been analyzed. $adminCount out of $totalCount users ($percentage%) have AdminCount set to 1.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserAdminCountCount"

    return $testResult
}


