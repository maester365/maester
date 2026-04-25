function Test-MtAdUserDelegationAllowedCount {
    <#
    .SYNOPSIS
    Counts user accounts that are trusted for Kerberos delegation.

    .DESCRIPTION
    This test identifies user accounts that allow unconstrained or constrained Kerberos
    delegation. Delegation-capable accounts can be abused for privilege escalation or
    lateral movement if they are not tightly controlled.

    .EXAMPLE
    Test-MtAdUserDelegationAllowedCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserDelegationAllowedCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }

    $users = @($adState.Users)
    $delegatedUsers = @($users | Where-Object {
            $_.TrustedForDelegation -eq $true -or $_.TrustedToAuthForDelegation -eq $true
        })
    $unconstrainedCount = @($delegatedUsers | Where-Object { $_.TrustedForDelegation -eq $true }).Count
    $protocolTransitionCount = @($delegatedUsers | Where-Object { $_.TrustedToAuthForDelegation -eq $true }).Count
    $delegatedCount = $delegatedUsers.Count
    $enabledCount = @($users | Where-Object { $_.Enabled -eq $true }).Count
    $totalCount = $users.Count

    $testResult = $null -ne $adState.Users

    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($delegatedCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Users | $totalCount |`n"
        $result += "| Enabled Users | $enabledCount |`n"
        $result += "| Users with Any Delegation | $delegatedCount |`n"
        $result += "| Trusted for Delegation | $unconstrainedCount |`n"
        $result += "| Trusted to Auth for Delegation | $protocolTransitionCount |`n"
        $result += "| Delegation Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory user objects have been analyzed. $delegatedCount out of $totalCount users ($percentage%) are configured for Kerberos delegation.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
