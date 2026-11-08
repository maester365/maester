function Test-MtAdUserAdminCountCount {
    <# .SYNOPSIS
    Inventories users with AdminCount set for privilege review.
    #>
    [MaesterTest(Id = 'AD-USER-11', Title = 'AdminCount users should be reviewed', Product = 'ad', Feature = 'users', Area = 'privileged-access', ResourceType = 'User', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory', Permission = 'ActiveDirectory:Ldap:user:ReadProperty', Author = 'soulemike')]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object { $_.AdminCount -eq 1 })
    Add-MtTestResultDetail -Result "Review $($found.Count) users with AdminCount=1. This flag can persist after privilege removal and does not alone prove current administrator rights.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Enabled', 'AdminCount', 'DistinguishedName'))" -Investigate
    return $true
}
