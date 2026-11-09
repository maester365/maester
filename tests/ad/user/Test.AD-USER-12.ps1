function Test-MtAdUserNonStandardPrimaryGroupCount {
    <# .SYNOPSIS
    Checks for ordinary users with unapproved primary group IDs.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-12
    Assess ordinary users for unapproved primary group IDs.
    .LINK
    https://maester.dev/docs/tests/AD-USER-12
    #>
    [MaesterTest(
        Id = 'AD-USER-12',
        Title = 'Ordinary users should use an approved primary group',
        Product = 'ad',
        Feature = 'users',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Primary group RID values permitted for ordinary user accounts.
        [ValidatePattern('^[0-9]+$')]
        [string[]] $AllowedPrimaryGroupIds = @('513')
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $allowedIds = @($AllowedPrimaryGroupIds | ForEach-Object { [int]$_ })
    $unknown = @($state.Users | Where-Object { (Test-MtAdUserOrdinaryIdentity $_) -and $null -eq $_.PrimaryGroupId })
    if ($unknown.Count) { throw "PrimaryGroupId missing for $($unknown.Count) ordinary users." }
    $found = @($state.Users | Where-Object { (Test-MtAdUserOrdinaryIdentity $_) -and $allowedIds -notcontains [int]$_.PrimaryGroupId })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) ordinary users with unapproved primary groups. Review effective membership and approve exceptions before changing groups.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'PrimaryGroupId', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result 'Well done. Ordinary users have approved primary group IDs.' }
    return ($found.Count -eq 0)
}
