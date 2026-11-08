function Test-MtAdUserDelegationAllowedCount {
    <# .SYNOPSIS
    Detects user accounts trusted for unconstrained delegation and inventories other delegation modes.
    #>
    [MaesterTest(Id = 'AD-USER-05', Title = 'No user should have unconstrained Kerberos delegation', Product = 'ad', Feature = 'permissions', Area = 'authentication', ResourceType = 'User', Severity = 'High', UserImpact = 'Low', ImplementationCost = 'Medium', Mitre = ('T1558', 'T1550.003'), Control = 'nist-800-53-r5:AC-6', Service = 'ActiveDirectory', Permission = 'ActiveDirectory:Ldap:user:ReadProperty', Author = 'soulemike')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    Assert-MtAdUserAccountControl -Users @($state.Users)
    $unconstrained = @($state.Users | Where-Object { $_.TrustedForDelegation -eq $true -or ($null -ne $_.UserAccountControl -and (([int64]$_.UserAccountControl -band 0x80000) -ne 0)) })
    $constrained = @($state.Users | Where-Object { @($_.AllowedToDelegateTo | Where-Object { $null -ne $_ }).Count -gt 0 -or $_.TrustedToAuthForDelegation -eq $true -or $_.HasResourceBasedConstrainedDelegation -eq $true })
    $reviewAccounts = @(@($unconstrained) + @($constrained) | Sort-Object DistinguishedName -Unique)
    $table = Format-MtAdUserSecurityTable $reviewAccounts @('SamAccountName', 'Enabled', 'TrustedForDelegation', 'TrustedToAuthForDelegation', 'AllowedToDelegateTo', 'HasResourceBasedConstrainedDelegation', 'DistinguishedName')
    if ($unconstrained.Count) { Add-MtTestResultDetail -Result "Found $($unconstrained.Count) users with unconstrained delegation; restrict or migrate delegation. $($constrained.Count) users have constrained/protocol-transition/resource-based indicators that require separate review; a protocol-transition flag alone does not establish a constrained delegation target.`n`n$table" }
    elseif ($constrained.Count) { Add-MtTestResultDetail -Result "No unconstrained delegation found. Review $($constrained.Count) users with constrained/protocol-transition/resource-based delegation indicators; no claim of unconstrained delegation is made.`n`n$table" -Investigate }
    else { Add-MtTestResultDetail -Result 'Well done. No user delegation indicators were found.' }
    return ($unconstrained.Count -eq 0)
}
