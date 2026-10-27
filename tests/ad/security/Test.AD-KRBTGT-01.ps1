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
        Title = 'KRBTGT password age should not exceed the configured maximum',
        Product = 'ad',
        Feature = 'account-security',
        Area = 'authentication',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1558.001',
        Control = 'nist-800-53-r5:IA-5',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:user:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum allowed age of the KRBTGT password, in days.
        [ValidateRange(1, 3650)] [int] $MaxPasswordAgeDays = 180
    )

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

    $passwordAgeDaysExact = if ($daysSinceChange) { $daysSinceChange.TotalDays } else { [int]::MaxValue }
    $passwordAgeDays = if ($daysSinceChange) { [Math]::Round($daysSinceChange.TotalDays, 0) } else { [int]::MaxValue }

    $maxAge = $MaxPasswordAgeDays
    $testResult = $passwordAgeDaysExact -le $maxAge

    $result = "| Property | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Account Name | $($krbtgt.SamAccountName) |" + "`n"
    $result += "| Password Last Set | $(if ($passwordLastSet) { $passwordLastSet.ToString('yyyy-MM-dd HH:mm:ss') } else { 'Never' }) |" + "`n"
    if ($daysSinceChange) {
        $result += "| Days Since Change | $passwordAgeDays |" + "`n"
    }
    $result += "| Account Enabled | $($krbtgt.Enabled) |" + "`n"
    Write-Verbose "Counts computed"

    $testResultMarkdown = "KRBTGT account password information retrieved. This account is used for Kerberos ticket encryption.`n`n%TestResult%"
    if ($testResult) {
        $remainingDays = $maxAge - $passwordAgeDays
        if ($remainingDays -le 0) {
            $analysisSummary = "The KRBTGT password was last set $passwordAgeDays days ago and reaches the maximum age threshold ($maxAge days) today."
        } else {
            $analysisSummary = "The KRBTGT password was last set $passwordAgeDays days ago and will not exceed the maximum age threshold ($maxAge days) for another $remainingDays days."
        }
        $testResultMarkdown = "$analysisSummary`n`n$testResultMarkdown"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdKrbtgtPasswordLastSet"

    return $testResult
}
