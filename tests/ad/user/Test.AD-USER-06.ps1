function Test-MtAdUserKerberosDesOnlyCount {
    <# .SYNOPSIS
    Detects users configured for obsolete DES-only Kerberos keys.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-06
    Assess whether any users require obsolete DES-only Kerberos keys.
    .LINK
    https://maester.dev/docs/tests/AD-USER-06
    #>
    [MaesterTest(
        Id = 'AD-USER-06',
        Title = 'No user should require DES-only Kerberos keys',
        Product = 'ad',
        Feature = 'users',
        Area = 'authentication',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1558',
        Control = 'nist-800-53-r5:IA-5',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    Assert-MtAdUserAccountControl -Users @($state.Users)
    $found = @($state.Users | Where-Object { $_.UseDESKeyOnly -eq $true -or ($null -ne $_.UserAccountControl -and (([int64]$_.UserAccountControl -band 0x200000) -ne 0)) })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) DES-only users. Migrate dependent services to modern Kerberos encryption and remove DES-only configuration.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Enabled', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result 'Well done. No user is configured for DES-only Kerberos keys.' }
    return ($found.Count -eq 0)
}
