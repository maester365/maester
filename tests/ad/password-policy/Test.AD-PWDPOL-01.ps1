function Test-MtAdDefaultPasswordPolicySecurity {
    <#
    .SYNOPSIS
    Evaluates the normalized default domain password policy against configured safeguards.
    #>
    [MaesterTest(
        Id = 'AD-PWDPOL-01', Title = 'Default domain password policy should meet configured safeguards',
        Product = 'ad', Feature = 'password-policy', Area = 'authentication', ResourceType = 'Tenant',
        Severity = 'High', UserImpact = 'Medium', ImplementationCost = 'Medium', Mitre = 'T1110',
        Service = 'ActiveDirectory', Permission = ('ActiveDirectory:Ldap:domainDNS.pwdHistoryLength:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.maxPwdAge:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.minPwdAge:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.minPwdLength:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.pwdProperties:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.lockoutDuration:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.lockoutThreshold:ReadProperty', 'ActiveDirectory:Ldap:domainDNS.lockOutObservationWindow:ReadProperty'), Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Select current NIST guidance or organization-defined legacy rotation.
        [ValidateSet('CurrentNist', 'LegacyRotation')][string] $Profile = 'CurrentNist',
        # Override profile minimum; 0 selects 15 (current) or 14 (legacy).
        [ValidateRange(0, 255)][int] $MinimumLength = 0,
        # Microsoft baseline password history minimum (not a NIST requirement).
        [ValidateRange(0, 255)][int] $MinimumHistory = 24,
        # LegacyRotation maximum password age in days.
        [ValidateRange(1, 3650)][int] $MaximumAgeDays = 90,
        # Microsoft baseline maximum failed logons before lockout.
        [ValidateRange(1, 1000)][int] $MaximumLockoutThreshold = 10,
        # Automatic lockout minimum in minutes; zero means manual unlock.
        [ValidateRange(1, 10080)][int] $MinimumLockoutMinutes = 15,
        # Minimum reset window in minutes.
        [ValidateRange(1, 10080)][int] $MinimumResetMinutes = 15
    )
    $state = Get-MtADDomainState -Categories @('Domain')
    if ($null -eq $state -or $null -eq $state.Domain) { throw 'Default domain password policy was not returned.' }
    $evaluation = Test-MtAdPasswordPolicyConfiguration -Policy $state.Domain -Profile $Profile -MinimumLength $MinimumLength -MinimumHistory $MinimumHistory -MaximumAgeDays $MaximumAgeDays -MaximumLockoutThreshold $MaximumLockoutThreshold -MinimumLockoutMinutes $MinimumLockoutMinutes -MinimumResetMinutes $MinimumResetMinutes
    $table = "| Setting | Actual | Expected | Status |`n| --- | --- | --- | --- |`n$($evaluation.Rows -join "`n")"
    if ($evaluation.Passed) {
        Add-MtTestResultDetail -Result "Well done. The default domain password policy meets the $Profile settings assessed here. Complexity under CurrentNist is observational; separately verify the password blocklist and MFA.`n`n$table"
    } else {
        Add-MtTestResultDetail -Result "The default domain password policy fails one or more $Profile settings; correct the listed values. Complexity under CurrentNist is observational; separately verify the password blocklist and MFA.`n`n$table"
    }
    return $evaluation.Passed
}
