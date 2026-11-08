function Test-MtAdUserNoPreAuthCount {
    <# .SYNOPSIS
    Detects users that do not require Kerberos pre-authentication.
    #>
    [MaesterTest(Id = 'AD-USER-07', Title = 'All users should require Kerberos pre-authentication', Product = 'ad', Feature = 'users', Area = 'authentication', ResourceType = 'User', Severity = 'High', UserImpact = 'Low', ImplementationCost = 'Medium', Mitre = 'T1558.004', Control = 'nist-800-53-r5:IA-2', Service = 'ActiveDirectory', Permission = 'ActiveDirectory:Ldap:user:ReadProperty', Author = 'soulemike')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    Assert-MtAdUserAccountControl -Users @($state.Users)
    $found = @($state.Users | Where-Object { $_.DoesNotRequirePreAuth -eq $true -or ($null -ne $_.UserAccountControl -and (([int64]$_.UserAccountControl -band 0x400000) -ne 0)) })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) users exposed to AS-REP roasting. Require Kerberos pre-authentication after validating dependencies.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Enabled', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result 'Well done. All users require Kerberos pre-authentication.' }
    return ($found.Count -eq 0)
}
