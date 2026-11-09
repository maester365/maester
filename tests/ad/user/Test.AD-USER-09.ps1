function Test-MtAdUserPasswordNotRequiredCount {
    <# .SYNOPSIS
    Detects users with the password-not-required account control flag.
    .EXAMPLE
    Invoke-MtTest -Id AD-USER-09
    Assess PasswordNotRequired flags; investigate incomplete account data.
    .LINK
    https://maester.dev/docs/tests/AD-USER-09
    #>
    [MaesterTest(
        Id = 'AD-USER-09',
        Title = 'No user should have PasswordNotRequired set',
        Product = 'ad',
        Feature = 'users',
        Area = 'authentication',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1078.002',
        Control = 'nist-800-53-r5:IA-5',
        Service = 'ActiveDirectory',
        Permission = 'ActiveDirectory:Ldap:user:ReadProperty',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $state = Get-MtADDomainState -Categories @('Users')
    if ($null -eq $state.Users) { throw 'AD user data was not returned.' }
    Assert-MtAdUserAccountControl -Users @($state.Users)
    $found = @($state.Users | Where-Object { $_.PasswordNotRequired -eq $true -or ($null -ne $_.UserAccountControl -and (([int64]$_.UserAccountControl -band 0x20) -ne 0)) })
    if (@($found | Where-Object { $null -eq $_.Enabled }).Count -gt 0) { throw 'Enabled state is unavailable for password-not-required accounts.' }
    $findings = @($found | Where-Object { $_.Enabled -eq $true -or (Test-MtAdUserOrdinaryIdentity $_) })
    $protectedReview = @($found | Where-Object { $_.Enabled -eq $false -and -not (Test-MtAdUserOrdinaryIdentity $_) })
    $enabledCount = @($found | Where-Object { $_.Enabled -eq $true }).Count
    if ($findings.Count) { Add-MtTestResultDetail -Result "Found $($findings.Count) enabled or ordinary accounts with the PASSWORD_NOT_REQUIRED flag. Review password requirements; the flag alone does not prove a blank password. $($protectedReview.Count) protected disabled built-ins are shown for review, not counted as failures.`n`n| Metric | Count |`n| --- | --- |`n| Enabled users with password not required | $enabledCount |`n`n$(Format-MtAdUserSecurityTable $found @('SamAccountName', 'Enabled', 'PasswordNotRequired', 'DistinguishedName'))" }
    elseif ($protectedReview.Count) { Add-MtTestResultDetail -Result "Only protected disabled built-ins have PASSWORD_NOT_REQUIRED; review their expected state without treating them as active password exposure.`n`n$(Format-MtAdUserSecurityTable $protectedReview @('SamAccountName', 'Enabled', 'PasswordNotRequired', 'DistinguishedName'))" -Investigate }
    else { Add-MtTestResultDetail -Result 'Well done. No user has the PASSWORD_NOT_REQUIRED flag.' }
    return ($findings.Count -eq 0)
}
