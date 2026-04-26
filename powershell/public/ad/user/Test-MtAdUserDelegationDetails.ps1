function Test-MtAdUserDelegationDetails {
    <#
    .SYNOPSIS
    Returns delegation details for users with delegation configured.

    .DESCRIPTION
    This test provides a per-user breakdown of delegation-related settings found
    on Active Directory user objects. The output helps identify whether risky
    user-based service accounts are configured for unconstrained delegation,
    protocol transition, or both.

    .EXAMPLE
    Test-MtAdUserDelegationDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserDelegationDetails
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
        } | ForEach-Object {
            $delegationType = if ($_.TrustedForDelegation -eq $true -and $_.TrustedToAuthForDelegation -eq $true) {
                'Unconstrained + Protocol Transition'
            } elseif ($_.TrustedForDelegation -eq $true) {
                'Unconstrained'
            } else {
                'Constrained/Protocol Transition'
            }

            [PSCustomObject]@{
                SamAccountName    = $_.SamAccountName
                Name              = $_.Name
                Enabled           = $_.Enabled
                DelegationType    = $delegationType
                TrustedForDelegation = $_.TrustedForDelegation
                TrustedToAuthForDelegation = $_.TrustedToAuthForDelegation
                HasSpn            = @($_.ServicePrincipalName).Count -gt 0
                DistinguishedName = $_.DistinguishedName
            }
        } | Sort-Object SamAccountName)

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Users with Any Delegation Setting | $(($delegatedUsers | Measure-Object).Count) |`n"
    $result += "| Unconstrained Delegation | $((@($delegatedUsers | Where-Object { $_.TrustedForDelegation -eq $true }) | Measure-Object).Count) |`n"
    $result += "| Protocol Transition Enabled | $((@($delegatedUsers | Where-Object { $_.TrustedToAuthForDelegation -eq $true }) | Measure-Object).Count) |`n`n"

    if ($delegatedUsers.Count -gt 0) {
        $result += "### Delegation Details`n`n"
        $result += "| SamAccountName | Display Name | Enabled | Delegation Type | Has SPN |`n"
        $result += "| --- | --- | --- | --- | --- |`n"
        foreach ($user in ($delegatedUsers | Select-Object -First 25)) {
            $result += "| $($user.SamAccountName) | $($user.Name) | $($user.Enabled) | $($user.DelegationType) | $($user.HasSpn) |`n"
        }

        if ($delegatedUsers.Count -gt 25) {
            $result += "| ... | ... | ... | ... | ... ($($delegatedUsers.Count - 25) more) |`n"
        }
    } else {
        $result += "No users with delegation-related settings were identified.`n"
    }

    $testResultMarkdown = "Delegation-enabled Active Directory user details were retrieved.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


