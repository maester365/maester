function Test-MtAdUserBuiltInAdminLastLogonDetails {
    <#
    .SYNOPSIS
    Returns last logon details for built-in administrator style accounts.

    .DESCRIPTION
    This test reports when built-in administrator style accounts last logged on.
    Reviewing recent and historical activity for these accounts helps identify
    stale privileged identities, unexpected usage, and potential incident leads.

    .EXAMPLE
    Test-MtAdUserBuiltInAdminLastLogonDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserBuiltInAdminLastLogonDetails
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

    $builtInAdminUsers = @($users | Where-Object {
            $sidValue = [string]$_.SID
            $sidValue -match '-500$' -or $_.isCriticalSystemObject -eq $true
        } | Sort-Object SamAccountName)

    $testResult = $true

    $result = "### Built-In Administrator Last Logon Details`n`n"
    $result += "| SamAccountName | Display Name | Enabled | Last Logon | Days Since Last Logon |`n"
    $result += "| --- | --- | --- | --- | --- |`n"

    if ($builtInAdminUsers.Count -gt 0) {
        foreach ($user in $builtInAdminUsers) {
            $lastLogonText = if ($null -ne $user.LastLogonDate) { Get-Date $user.LastLogonDate -Format 'yyyy-MM-dd HH:mm:ss' } else { 'Never/Unknown' }
            $daysSinceLogon = if ($null -ne $user.LastLogonDate) { [int](((Get-Date) - $user.LastLogonDate).TotalDays) } else { 'N/A' }
            $result += "| $($user.SamAccountName) | $($user.Name) | $($user.Enabled) | $lastLogonText | $daysSinceLogon |`n"
        }
    } else {
        $result += "| No built-in administrator style accounts found | - | - | - | - |`n"
    }

    $testResultMarkdown = "Built-in administrator style account last logon data was retrieved from Active Directory.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


