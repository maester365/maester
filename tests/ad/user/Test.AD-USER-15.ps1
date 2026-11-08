function Test-MtAdUserManagerSetCount {
    <# .SYNOPSIS
    Checks for enabled ordinary users missing a manager for access review.
    #>
    [MaesterTest(Id = 'AD-USER-15', Title = 'Enabled ordinary users should have a manager', Product = 'ad', Feature = 'users', Area = 'identity-lifecycle', ResourceType = 'User', Severity = 'Low', UserImpact = 'Low', ImplementationCost = 'Medium', Mitre = 'None', Control = 'nist-800-53-r5:AC-2', Service = 'ActiveDirectory', Permission = 'ActiveDirectory:Ldap:user:ReadProperty', Author = 'soulemike')]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Ordinary account IDs (sAMAccountName or distinguished name) without a manager by design.
        [string[]] $ExcludedUsers = @()
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object { $_.Enabled -eq $true -and (Test-MtAdUserOrdinaryIdentity $_) -and [string]::IsNullOrWhiteSpace($_.Manager) -and $ExcludedUsers -notcontains $_.SamAccountName -and $ExcludedUsers -notcontains $_.DistinguishedName })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) enabled ordinary users without a manager. Assign owners or document exclusions for access reviews.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result 'Well done. Enabled ordinary users have managers or approved exclusions.' }
    return ($found.Count -eq 0)
}
