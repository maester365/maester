function Test-MtAdUserHomeDirectoryCount {
    <#
    .SYNOPSIS
    Counts users with a home directory configured in Active Directory.

    .DESCRIPTION
    This test identifies user objects where the HomeDirectory attribute is populated.
    Home directories can indicate legacy file storage models, mapped drive usage, or
    sensitive data locations tied directly to account provisioning. Knowing how many
    accounts use this attribute helps assess operational dependencies and cleanup needs.

    .EXAMPLE
    Test-MtAdUserHomeDirectoryCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with a home directory configured.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserHomeDirectoryCount
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
    $usersWithHomeDirectory = $users | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.HomeDirectory)
    }

    $homeDirectoryCount = ($usersWithHomeDirectory | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($homeDirectoryCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with Home Directory | $homeDirectoryCount |`n"
        $result += "| Home Directory Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory users have been analyzed. $homeDirectoryCount out of $totalCount users ($percentage%) have the HomeDirectory attribute populated.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


