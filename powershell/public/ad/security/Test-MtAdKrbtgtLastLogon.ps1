function Test-MtAdKrbtgtLastLogon {
    <#
    .SYNOPSIS
    Checks the KRBTGT account last logon time.

    .DESCRIPTION
    The KRBTGT account is a service account that should never have interactive logons.
    This test retrieves the last logon timestamp for the KRBTGT account, which should
    typically show no logon activity or only system-generated authentication events.

    Security Note:
    - KRBTGT should not have interactive logons
    - Any logon activity may indicate suspicious activity
    - The account is used internally by the KDC service only

    .EXAMPLE
    Test-MtAdKrbtgtLastLogon

    Returns $true if KRBTGT account data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKrbtgtLastLogon
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $users = $adState.Users
    $krbtgt = $users | Where-Object { $_.SamAccountName -eq 'krbtgt' } | Select-Object -First 1

    if ($null -eq $krbtgt) {
        Add-MtTestResultDetail -Result "KRBTGT account not found in Active Directory."
        return $false
    }

    $lastLogon = $krbtgt.LastLogonDate
    $testResult = $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Account Name | $($krbtgt.SamAccountName) |`n"
    $result += "| Last Logon Date | $(if ($lastLogon) { $lastLogon.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Never' }) |`n"
    $result += "| Account Enabled | $($krbtgt.Enabled) |`n"
    $result += "| Password Last Set | $(if ($krbtgt.PasswordLastSet) { $krbtgt.PasswordLastSet.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Never' }) |`n"

    $testResultMarkdown = "KRBTGT account last logon information retrieved. This service account should not have interactive logons.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


