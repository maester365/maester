function Test-MtAdUserEffectivePasswordExpiration {
    <#
    .SYNOPSIS
    Assesses password expiration for enabled users using their effective policy and account override.
    #>
    [MaesterTest(
        Id = 'AD-USER-03',
        Title = 'Enabled users should meet the selected effective password expiration policy',
        Product = 'ad',
        Feature = 'users',
        Area = 'authentication',
        ResourceType = 'User',
        Severity = 'Low',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:user:ReadProperty', 'ActiveDirectory:Ldap:msDS-PasswordSettings:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # CurrentNist does not require periodic rotation; LegacyRotation enforces it.
        [ValidateSet('CurrentNist', 'LegacyRotation')][string] $Profile = 'CurrentNist',
        # Maximum allowed age in days for organization-selected LegacyRotation.
        [ValidateRange(1, 3650)][int] $MaximumAgeDays = 90,
        # Confirm complete access to PSOs and computed user resultant-policy attributes.
        [bool] $PolicyInventoryReadAccessConfirmed = $false
    )

    $state = Get-MtADDomainState -Categories @('Domain', 'FineGrainedPasswordPolicies', 'Users')
    if ($null -eq $state -or $null -eq $state.Domain -or $null -eq $state.Users -or $null -eq $state.FineGrainedPasswordPolicies) {
        throw 'Domain, user or PSO inventory was not returned.'
    }
    $users = @($state.Users)
    $policies = @($state.FineGrainedPasswordPolicies)
    $usage = Get-MtAdPasswordPolicyUsage -Users $users -Policies $policies
    if ($usage.EnabledCount -eq 0) {
        Add-MtTestResultDetail -Result 'No enabled users were visible; effective password expiration cannot be established.' -Investigate
        return $true
    }
    $policyByDn = @{}
    foreach ($policy in $policies) { $policyByDn[[string]$policy.DistinguishedName] = $policy }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| User | Effective policy | NeverExpires override | Max age | Status |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- |') | Out-Null
    $passed = $true
    $unknownDefault = $false
    $overrideReview = $false
    foreach ($user in $users) {
        if (-not $user.Enabled) { continue }
        if ($null -eq $user.PSObject.Properties['PasswordNeverExpires'] -or $null -eq $user.PasswordNeverExpires) {
            throw "PasswordNeverExpires is missing for enabled user '$($user.Name)'."
        }
        $dn = [string]$user.ResultantPasswordPolicyDN
        if ([string]::IsNullOrWhiteSpace($dn) -and -not $PolicyInventoryReadAccessConfirmed) {
            $unknownDefault = $true
            $lines.Add("| $($user.Name) | Unconfirmed default-policy visibility | $($user.PasswordNeverExpires) | Unknown | Investigate |") | Out-Null
            continue
        }
        $policy = if ([string]::IsNullOrWhiteSpace($dn)) { $state.Domain } else { $policyByDn[$dn] }
        if ($null -eq $policy -or $null -eq $policy.PSObject.Properties['MaxPwdAge'] -or $null -eq $policy.MaxPwdAge -or $policy.MaxPwdAge -isnot [timespan]) {
            throw "MaxPwdAge is missing or invalid for effective policy of '$($user.Name)'."
        }
        $age = [math]::Abs($policy.MaxPwdAge.TotalDays)
        $valid = if ($Profile -eq 'CurrentNist') { $age -eq 0 } else { -not $user.PasswordNeverExpires -and $age -gt 0 -and $age -le $MaximumAgeDays }
        if ($Profile -eq 'CurrentNist' -and $user.PasswordNeverExpires) { $overrideReview = $true }
        if (-not $valid) { $passed = $false }
        $policyName = if ([string]::IsNullOrWhiteSpace($dn)) { 'Default domain' } else { $policy.Name }
        $status = if ($valid) { 'Pass' } else { 'Fail' }
        $lines.Add("| $($user.Name) | $policyName | $($user.PasswordNeverExpires) | $age days | $status |") | Out-Null
    }
    $table = $lines -join "`n"
    if (-not $passed) {
        Add-MtTestResultDetail -Result "Some visible enabled users do not meet the $Profile password expiration policy criterion. Correct the effective PSO/default policy; do not set per-account PasswordNeverExpires merely to satisfy CurrentNist. Review account overrides separately. Unconfirmed default-policy rows do not hide known failures.`n`n$table"
        return $false
    }
    if ($unknownDefault -or $overrideReview -or -not $PolicyInventoryReadAccessConfirmed) {
        Add-MtTestResultDetail -Result "Review unconfirmed default-policy visibility or per-account PasswordNeverExpires overrides separately. CurrentNist is satisfied through the effective policy, not account overrides; this is not proof of complete policy coverage.`n`n$table" -Investigate
        return $true
    }
    Add-MtTestResultDetail -Result "Well done. Visible enabled users meet the $Profile effective password expiration criterion; this does not verify compromise response or MFA.`n`n$table"
    return $true
}
