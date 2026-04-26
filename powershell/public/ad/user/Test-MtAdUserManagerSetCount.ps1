function Test-MtAdUserManagerSetCount {
    <#
    .SYNOPSIS
    Counts users with the manager attribute set in Active Directory.

    .DESCRIPTION
    This test identifies user objects where the Manager attribute is populated.
    While this is not inherently a security issue, manager relationships are often
    used in approval workflows, access reviews, and delegated business processes.
    Understanding coverage helps assess the reliability of identity governance data.

    .EXAMPLE
    Test-MtAdUserManagerSetCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with a manager assigned.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserManagerSetCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }

    $users = $adState.Users
    $usersWithManager = $users | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.Manager)
    }

    $managerCount = ($usersWithManager | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($managerCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with Manager Set | $managerCount |`n"
        $result += "| Manager Coverage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory users have been analyzed. $managerCount out of $totalCount users ($percentage%) have the Manager attribute populated.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


