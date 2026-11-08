function Test-MtAdUserWorkstationRestrictionCount {
    <# .SYNOPSIS
    Inventories user accounts with logon workstation restrictions for review.
    #>
    [MaesterTest(
        Id = 'AD-USER-10',
        Title = 'User workstation restrictions should be reviewed',
        Product = 'ad',
        Feature = 'users',
        Area = 'access-control',
        ResourceType = 'User',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object { -not [string]::IsNullOrWhiteSpace($_.LogonWorkstations) })
    Add-MtTestResultDetail -Result "Review $($found.Count) users with workstation restrictions (an empty restriction is not proof of risk).`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Enabled', 'LogonWorkstations'))" -Investigate
    return $true
}
