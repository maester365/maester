function Test-MtAdUserDisabledCount {
    <#
    .SYNOPSIS
    Counts the number of disabled user objects in Active Directory.

    .DESCRIPTION
    This test analyzes Active Directory user objects and counts how many accounts are
    currently disabled. Disabled accounts are often expected during offboarding or
    service account lifecycle management, but tracking them helps validate directory
    hygiene and identify stale objects that should be removed.

    .EXAMPLE
    Test-MtAdUserDisabledCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserDisabledCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserDisabledCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user disabled count"

    $users = @($adState.Users)
    $disabledUsers = @($users | Where-Object { $_.Enabled -eq $false })
    $disabledCount = $disabledUsers.Count
    $enabledCount = @($users | Where-Object { $_.Enabled -eq $true }).Count
    $totalCount = $users.Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($disabledCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Disabled Users | $disabledCount |`n"
        $result += "| Disabled Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $disabledCount out of $totalCount users ($percentage%) are disabled.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserDisabledCount"

    return $testResult
}


