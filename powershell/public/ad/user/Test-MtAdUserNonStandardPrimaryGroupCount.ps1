function Test-MtAdUserNonStandardPrimaryGroupCount {
    <#
    .SYNOPSIS
    Counts users with a non-standard primary group in Active Directory.

    .DESCRIPTION
    This test identifies user objects whose PrimaryGroupId is not set to 513
    (Domain Users). A non-standard primary group can be legitimate in some cases,
    but it is uncommon and may indicate privileged configurations, legacy migrations,
    or unusual access control requirements that should be validated.

    .EXAMPLE
    Test-MtAdUserNonStandardPrimaryGroupCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with a non-standard primary group.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserNonStandardPrimaryGroupCount
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
    $usersWithNonStandardPrimaryGroup = $users | Where-Object {
        $null -ne $_.primaryGroupId -and $_.primaryGroupId -ne 513
    }

    $nonStandardPrimaryGroupCount = ($usersWithNonStandardPrimaryGroup | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($nonStandardPrimaryGroupCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with PrimaryGroupId = 513 | $($totalCount - $nonStandardPrimaryGroupCount) |`n"
        $result += "| Users with Non-Standard Primary Group | $nonStandardPrimaryGroupCount |`n"
        $result += "| Non-Standard Primary Group Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory users have been analyzed. $nonStandardPrimaryGroupCount out of $totalCount users ($percentage%) have a primaryGroupId other than 513 (Domain Users).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
