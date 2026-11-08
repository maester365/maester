function Test-MtAdUserNeverLoggedInCount {
    <# .SYNOPSIS
    Detects enabled accounts with no recorded logon after their provisioning grace period.
    #>
    [MaesterTest(
        Id = 'AD-USER-08',
        Title = 'Enabled users should not remain unused after provisioning',
        Product = 'ad',
        Feature = 'users',
        Area = 'identity-lifecycle',
        ResourceType = 'User',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Control = 'nist-800-53-r5:AC-2(3)',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Minimum age in days before a newly created, never-logged-in account fails.
        [ValidateRange(1, 3650)]
        [int] $GraceDays = 30
    )

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    $unknown = @($state.Users | Where-Object { $_.Enabled -eq $true -and $null -eq $_.LastLogonDate -and $null -eq $_.Created })
    if ($unknown.Count) { throw "Creation time missing for $($unknown.Count) enabled users with no recorded logon." }
    $found = @($state.Users | Where-Object { $_.Enabled -eq $true -and $null -eq $_.LastLogonDate -and $null -ne $_.Created -and [datetime]$_.Created -lt (Get-Date).AddDays(-$GraceDays) })
    if ($found.Count) { Add-MtTestResultDetail -Result "Found $($found.Count) enabled users without a recorded logon after $GraceDays days. Confirm usage in authoritative logs before disabling: lastLogonTimestamp may be missing or lag.`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Created', 'DistinguishedName'))" }
    else { Add-MtTestResultDetail -Result "Well done. No enabled account older than $GraceDays days lacks a recorded logon; verify actual usage with sign-in logs." }
    return ($found.Count -eq 0)
}
