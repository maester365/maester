function Test-MtAdUserInContainerCount {
    <# .SYNOPSIS
    Finds ordinary users beneath CN containers instead of OUs.
    #>
    [MaesterTest(Id = 'AD-USER-19', Title = 'Ordinary users should be managed in organizational units', Product = 'ad', Feature = 'users', Area = 'identity-lifecycle', ResourceType = 'User', Severity = 'Low', UserImpact = 'Low', ImplementationCost = 'Medium', Mitre = 'None', Service = 'ActiveDirectory', Permission = 'ActiveDirectory:Ldap:user:ReadProperty', Author = 'soulemike')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object {
        if (-not (Test-MtAdUserOrdinaryIdentity $_)) { return $false }
        $dn = [string]$_.DistinguishedName
        if ([string]::IsNullOrWhiteSpace($dn)) { throw "Distinguished name missing for $($_.SamAccountName)." }
        # A comma escaped with backslash is part of an RDN, not a DN separator.
        $parts = [regex]::Split($dn, '(?<!\\)(?:\\\\)*,')
        @($parts | Select-Object -Skip 1 | Where-Object { $_ -match '^CN=' }).Count -gt 0
    })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) ordinary users in CN containers. Review policy/delegation requirements and move eligible users to managed OUs.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result 'Well done. Ordinary users are not stored under CN containers.' }
    return ($found.Count -eq 0)
}
