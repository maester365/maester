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
    [MaesterTest(
        Id = 'AD-KRBTGT-01',
        Title = 'KRBTGT password age should not exceed 180 days',
        Severity = 'High',
        Category = 'Active Directory - Security Accounts',
        Product = 'Active Directory',
        Tag = 'AD.Security',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdKrbtgtPasswordLastSet"
    $adState = Get-MtADDomainState -Categories @('Users')
    Write-Verbose "Retrieved AD state"

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }
    Write-Verbose "Filtering/counting krbtgt password last set"

    $users = $adState.Users
    $krbtgt = $users | Where-Object { $_.SamAccountName -eq 'krbtgt' } | Select-Object -First 1

    if ($null -eq $krbtgt) {
        Add-MtTestResultDetail -Result "KRBTGT account not found in Active Directory."
        return $null
    }

    $passwordLastSet = $krbtgt.PasswordLastSet
    $daysSinceChange = if ($passwordLastSet) { (Get-Date) - $passwordLastSet } else { $null }

    $passwordAgeDays = if ($daysSinceChange) { [Math]::Round($daysSinceChange.TotalDays, 0) } else { [int]::MaxValue }
    $maxAge = 180
    $testResult = $passwordAgeDays -le $maxAge

    $result = "| Property | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Account Name | $($krbtgt.SamAccountName) |" + "`n"
    $result += "| Password Last Set | $(if ($passwordLastSet) { $passwordLastSet.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Never' }) |" + "`n"
    if ($daysSinceChange) {
        $result += "| Days Since Change | $([Math]::Round($daysSinceChange.TotalDays, 0)) |" + "`n"
    }
    $result += "| Account Enabled | $($krbtgt.Enabled) |" + "`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "KRBTGT account password information retrieved. This account is used for Kerberos ticket encryption.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdKrbtgtPasswordLastSet"

    return $testResult
}
