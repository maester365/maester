function Test-MtAdUserScriptPathCount {
    <#
    .SYNOPSIS
    Counts users with a logon script configured in Active Directory.

    .DESCRIPTION
    This test identifies user objects where the ScriptPath attribute is populated.
    Logon scripts can execute automatically during sign-in and may point to legacy
    operational logic, network shares, or privileged automation. Tracking these
    accounts helps identify script-based dependencies and potential attack surface.

    .EXAMPLE
    Test-MtAdUserScriptPathCount

    Returns $true if user data is accessible, $false otherwise.
    The test result includes the count of users with a logon script configured.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserScriptPathCount
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
    $usersWithScriptPath = $users | Where-Object {
        -not [string]::IsNullOrWhiteSpace($_.ScriptPath)
    }

    $scriptPathCount = ($usersWithScriptPath | Measure-Object).Count
    $totalCount = ($users | Measure-Object).Count
    $testResult = $totalCount -gt 0

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($scriptPathCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Users with Script Path | $scriptPathCount |`n"
        $result += "| Script Path Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory users have been analyzed. $scriptPathCount out of $totalCount users ($percentage%) have the ScriptPath attribute populated.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory users. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


