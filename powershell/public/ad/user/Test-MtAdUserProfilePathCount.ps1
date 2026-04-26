function Test-MtAdUserProfilePathCount {
    <#
    .SYNOPSIS
    Counts users with a profile path configured in Active Directory.

    .DESCRIPTION
    This test identifies user objects where the ProfilePath attribute is populated.
    Roaming profile paths often reveal legacy workstation management approaches and
    file server dependencies. These paths can also expose centralized storage locations
    that should be reviewed for access control and modernization opportunities.

    .EXAMPLE
    Test-MtAdUserProfilePathCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with a profile path configured.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserProfilePathCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserProfilePathCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user profile path count"

    $users = $adState.Users
    $usersWithProfilePath = $users | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.ProfilePath)
    }

    $profilePathCount = ($usersWithProfilePath | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($profilePathCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with Profile Path | $profilePathCount |`n"
        $result += "| Profile Path Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory users have been analyzed. $profilePathCount out of $totalCount users ($percentage%) have the ProfilePath attribute populated.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserProfilePathCount"

    return $testResult
}


