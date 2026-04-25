function Test-MtAdUserDelegationConfiguredCount {
    <#
    .SYNOPSIS
    Counts users with delegation configured.

    .DESCRIPTION
    This test identifies user accounts with delegation-related settings enabled.
    Delegation can allow services to impersonate users and should be tightly
    controlled, especially for user-based service accounts.

    .EXAMPLE
    Test-MtAdUserDelegationConfiguredCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserDelegationConfiguredCount
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

    $delegatedUsers = @($users | Where-Object {
            $_.TrustedForDelegation -eq $true -or $_.TrustedToAuthForDelegation -eq $true
        })

    $unconstrainedCount = (@($delegatedUsers | Where-Object { $_.TrustedForDelegation -eq $true }) | Measure-Object).Count
    $protocolTransitionCount = (@($delegatedUsers | Where-Object { $_.TrustedToAuthForDelegation -eq $true }) | Measure-Object).Count
    $bothCount = (@($delegatedUsers | Where-Object { $_.TrustedForDelegation -eq $true -and $_.TrustedToAuthForDelegation -eq $true }) | Measure-Object).Count
    $totalCount = ($delegatedUsers | Measure-Object).Count

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Users Reviewed | $((@($users) | Measure-Object).Count) |`n"
    $result += "| Users with Any Delegation Setting | $totalCount |`n"
    $result += "| TrustedForDelegation Enabled | $unconstrainedCount |`n"
    $result += "| TrustedToAuthForDelegation Enabled | $protocolTransitionCount |`n"
    $result += "| Both Delegation Flags Enabled | $bothCount |`n"

    $testResultMarkdown = "Active Directory users were reviewed for delegation configuration.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
