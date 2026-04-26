function Test-MtAdUserBuiltInAdminEnabledDetails {
    <#
    .SYNOPSIS
    Returns enabled built-in administrator style user details.

    .DESCRIPTION
    This test lists enabled built-in administrator style accounts based on the
    RID 500 pattern and critical system object flag. These accounts deserve extra
    scrutiny because they are commonly targeted and often retain elevated rights.

    .EXAMPLE
    Test-MtAdUserBuiltInAdminEnabledDetails

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserBuiltInAdminEnabledDetails
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserBuiltInAdminEnabledDetails"
    $adState = Get-MtADDomainState
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Custom -SkippedCustomReason "Not connected to Active Directory."
        return $null
    }
    Write-Verbose "Filtering/counting user built in admin enabled details"

    $users = $adState.Users

    $enabledBuiltInAdmins = @($users | Where-Object {
            $sidValue = [string]$_.SID
            ($sidValue -match '-500$' -or $_.isCriticalSystemObject -eq $true) -and $_.Enabled -eq $true
        } | Sort-Object SamAccountName)

    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Enabled Built-In Administrator Style Accounts | $(($enabledBuiltInAdmins | Measure-Object).Count) |`n`n"

    if ($enabledBuiltInAdmins.Count -gt 0) {
        $result += "### Enabled Account Details`n`n"
        $result += "| SamAccountName | Display Name | SID | AdminCount | Last Logon |`n"
        $result += "| --- | --- | --- | --- | --- |`n"
        foreach ($user in $enabledBuiltInAdmins) {
            $lastLogon = if ($null -ne $user.LastLogonDate) { Get-Date $user.LastLogonDate -Format 'yyyy-MM-dd HH:mm:ss' } else { 'Never/Unknown' }
            $result += "| $($user.SamAccountName) | $($user.Name) | $([string]$user.SID) | $($user.AdminCount) | $lastLogon |`n"
        }
    } else {
        $result += "No enabled built-in administrator style accounts were found.`n"
    }
    Write-Verbose "Counts computed"

    $testResultMarkdown = "Enabled built-in administrator style Active Directory user details were retrieved.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserBuiltInAdminEnabledDetails"

    return $testResult
}


