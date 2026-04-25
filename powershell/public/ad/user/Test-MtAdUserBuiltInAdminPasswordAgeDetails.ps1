function Test-MtAdUserBuiltInAdminPasswordAgeDetails {
    <#
    .SYNOPSIS
    Returns password age details for built-in administrator style accounts.

    .DESCRIPTION
    This test reports when built-in administrator style accounts last changed
    their passwords. Long-lived credentials on highly privileged accounts can
    materially increase risk and should be reviewed regularly.

    .EXAMPLE
    Test-MtAdUserBuiltInAdminPasswordAgeDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserBuiltInAdminPasswordAgeDetails
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

    $result = "### Built-In Administrator Password Age Details`n`n"
    $result += "| SamAccountName | Display Name | Enabled | Password Last Set | Password Age (Days) | Password Never Expires |`n"
    $result += "| --- | --- | --- | --- | --- | --- |`n"

    if ($builtInAdminUsers.Count -gt 0) {
        foreach ($user in $builtInAdminUsers) {
            $passwordLastSetText = if ($null -ne $user.PasswordLastSet) { Get-Date $user.PasswordLastSet -Format 'yyyy-MM-dd HH:mm:ss' } else { 'Never/Unknown' }
            $passwordAgeDays = if ($null -ne $user.PasswordLastSet) { [int](((Get-Date) - $user.PasswordLastSet).TotalDays) } else { 'N/A' }
            $result += "| $($user.SamAccountName) | $($user.Name) | $($user.Enabled) | $passwordLastSetText | $passwordAgeDays | $($user.PasswordNeverExpires) |`n"
        }
    } else {
        $result += "| No built-in administrator style accounts found | - | - | - | - | - |`n"
    }

    $testResultMarkdown = "Built-in administrator style account password age data was retrieved from Active Directory.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
