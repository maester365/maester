function Test-MtAdKrbtgtPasswordLastSet {
    <#
    .SYNOPSIS
    Checks when the KRBTGT account password was last set.

    .DESCRIPTION
    The KRBTGT account is a critical service account used by the Key Distribution Center (KDC) service
    for Kerberos authentication. Its password is used to encrypt and sign all Kerberos tickets.
    This test retrieves the date when the KRBTGT password was last changed.

    Security Best Practice:
    - KRBTGT password should be rotated at least every 180 days
    - If domain compromise is suspected, rotate the password twice (with 10+ hours between)
    - The account should remain disabled (standard UAC = 514)

    .EXAMPLE
    Test-MtAdKrbtgtPasswordLastSet

    Returns $true if KRBTGT account data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdKrbtgtPasswordLastSet
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

    $passwordLastSet = $krbtgt.PasswordLastSet
    $daysSinceChange = if ($passwordLastSet) { (Get-Date) - $passwordLastSet } else { $null }

    $testResult = $true

    $result = "| Property | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Account Name | $($krbtgt.SamAccountName) |`n"
    $result += "| Password Last Set | $(if ($passwordLastSet) { $passwordLastSet.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Never' }) |`n"
    if ($daysSinceChange) {
        $result += "| Days Since Change | $([Math]::Round($daysSinceChange.TotalDays, 0)) |`n"
    }
    $result += "| Account Enabled | $($krbtgt.Enabled) |`n"

    $testResultMarkdown = "KRBTGT account password information retrieved. This account is used for Kerberos ticket encryption.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
