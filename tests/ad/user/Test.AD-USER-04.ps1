function Test-MtAdUserReversibleEncryptionCount {
    <#
    .SYNOPSIS
    Fails user accounts configured to allow reversible password encryption.

    .DESCRIPTION
    This test identifies user accounts where password storage may allow reversible
    encryption semantics. The test checks explicit reversible encryption-style flags if
    available and falls back to the userAccountControl bit commonly associated with this
    risky legacy configuration.

    .EXAMPLE
    Test-MtAdUserReversibleEncryptionCount

    .LINK
    https://maester.dev/docs/commands/Test-MtAdUserReversibleEncryptionCount
    #>
    [MaesterTest(
        Id = 'AD-USER-04',
        Title = 'User accounts should not allow reversible password encryption',
        Product = 'ad',
        Feature = 'users',
        Area = 'authentication',
        ResourceType = 'User',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1003.003',
        Control = 'nist-800-53-r5:IA-5(1)',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:user:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdUserReversibleEncryptionCount"
    $adState = Get-MtADDomainState -Categories @('Users')
    Write-Verbose "Retrieved AD state"
    if ($null -eq $adState -or $null -eq $adState.Users) {
        throw 'User inventory is unavailable; reversible encryption cannot be assessed.'
    }
    Write-Verbose "Filtering/counting user reversible encryption count"

    $users = @($adState.Users)
    Assert-MtAdUserAccountControl -Users $users
    $reversibleEncryptionUsers = @($users | Where-Object {
            $hasExplicitFlag = ($_.PSObject.Properties['ReversibleEncryption'] -and $_.ReversibleEncryption -eq $true) -or
            ($_.PSObject.Properties['AllowReversiblePasswordEncryption'] -and $_.AllowReversiblePasswordEncryption -eq $true)

            $hasUserAccountControlFlag = $_.PSObject.Properties['userAccountControl'] -and
            ($_.userAccountControl -band 0x80)

            $hasExplicitFlag -or $hasUserAccountControlFlag
        })

    $reversibleEncryptionCount = $reversibleEncryptionUsers.Count
    $totalCount = $users.Count
    $enabledCount = @($users | Where-Object { $_.Enabled -eq $true }).Count

    $testResult = $reversibleEncryptionCount -eq 0

    if ($null -ne $adState.Users) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($reversibleEncryptionCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Users | $totalCount |" + "`n"
        $result += "| Enabled Users | $enabledCount |" + "`n"
        $result += "| Users with Reversible Encryption | $reversibleEncryptionCount |" + "`n"
        $result += "| Reversible Encryption Percentage | $percentage% |" + "`n" + "`n"
    Write-Verbose "Counts computed"

        $table = Format-MtAdUserSecurityTable $reversibleEncryptionUsers @('SamAccountName', 'Enabled', 'DistinguishedName')
        $testResultMarkdown = "$(if ($testResult) { 'Well done. No user account permits reversible password encryption.' } else { 'User accounts permit reversible password encryption. Remove that setting, check the effective password policy and reset affected passwords after validating application dependencies.' }) This checks account configuration, not whether an existing plaintext-equivalent password was actually stored.`n`n%TestResult%`n`n$table"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory user objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    Write-Verbose "Completed Test-MtAdUserReversibleEncryptionCount"

    return $testResult
}
