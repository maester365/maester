function Test-MtAdUserKnownServiceAccountCount {
    <# .SYNOPSIS
    Inventories user names matching configurable service account naming patterns.
    #>
    [MaesterTest(
        Id = 'AD-USER-20',
        Title = 'Service-like user names should be reviewed',
        Product = 'ad',
        Feature = 'users',
        Area = 'applications',
        ResourceType = 'User',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Case-insensitive regular expressions used for both inventory count and details.
        [string[]] $RegexPatterns = @('^(svc|service|sa|app|web|api|batch|job|task|sql|db)[-_.]', '[-_.](svc|service|sa)$')
    )

    $compiled = foreach ($pattern in $RegexPatterns) { [regex]::new($pattern, [Text.RegularExpressions.RegexOptions]::IgnoreCase) }
    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $found = @($state.Users | Where-Object {
        $name = [string]$_.SamAccountName
        $display = [string]$_.Name
        @($compiled | Where-Object { $_.IsMatch($name) -or $_.IsMatch($display) }).Count -gt 0
    })
    Add-MtTestResultDetail -Result "Review $($found.Count) users matching the configured naming expressions. Names are not proof of service-account purpose, ownership or permissions.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Name', 'Enabled', 'PasswordNeverExpires', 'DistinguishedName'))" -Investigate
    return $true
}
