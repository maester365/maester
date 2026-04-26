function Test-MtAdUserNoPreAuthCount {
    <#
    .SYNOPSIS
    Counts user accounts that do not require Kerberos pre-authentication.

    .DESCRIPTION
    This test identifies user accounts with pre-authentication disabled. These accounts
    are more exposed to AS-REP roasting attacks because an attacker can request Kerberos
    material without proving knowledge of the password first.

    .EXAMPLE
    Test-MtAdUserNoPreAuthCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserNoPreAuthCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserNoPreAuthCount"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user no pre auth count"

    $users = @($adState.Users)
    $noPreAuthUsers = @($users | Where-Object {
            ($_.PSObject.Properties['DoesNotRequirePreAuth'] -and $_.DoesNotRequirePreAuth -eq $true) -or
            ($_.PSObject.Properties['userAccountControl'] -and ($_.userAccountControl -band 0x400000))
        })

    $noPreAuthCount = $noPreAuthUsers.Count
    $totalCount = $users.Count
    $enabledCount = @($users | Where-Object { $_.Enabled -eq $true }).Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($noPreAuthCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Users Without Pre-Authentication | $noPreAuthCount |`n"
        $result += "| No Pre-Authentication Percentage | $percentage% |`n`n"
    Write-Verbose "Counts computed"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $noPreAuthCount out of $totalCount users ($percentage%) do not require Kerberos pre-authentication.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserNoPreAuthCount"

    return $testResult
}


