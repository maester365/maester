function Get-MtAdFineGrainedPolicyAssessmentInstance {
    <#
    .SYNOPSIS
    Returns the fixed settings and usage assessments for the AD-FGPP-01 family.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param()

    [pscustomobject]@{
        Id = 'settings'
        Title = 'Fine-grained password policy security settings should meet configured safeguards'
        Severity = 'High'
        Data = [pscustomobject]@{ Kind = 'Settings' }
    }
    [pscustomobject]@{
        Id = 'usage'
        Title = 'Fine-grained password policies should exist and be used'
        Severity = 'Low'
        Data = [pscustomobject]@{ Kind = 'Usage' }
    }
}

function Test-MtAdFineGrainedPasswordPolicySecurity {
    <#
    .SYNOPSIS
    Evaluates fine-grained password policy security settings and effective usage in separate result rows.
    .EXAMPLE
    Invoke-MtTest -Id AD-FGPP-01
    Assess both fine-grained password policy settings and usage; missing unconfirmed inventory requires investigation.
    .LINK
    https://maester.dev/docs/tests/AD-FGPP-01
    #>
    [MaesterTest(
        Id = 'AD-FGPP-01',
        Title = 'Fine-grained password policies should meet configured safeguards and be in use',
        Product = 'ad',
        Feature = 'password-policy',
        Area = 'authentication',
        ResourceType = 'Policy',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Medium',
        Mitre = 'T1110',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:msDS-PasswordSettings:ReadProperty', 'ActiveDirectory:Ldap:user:ReadProperty'),
        InstanceSource = 'Get-MtAdFineGrainedPolicyAssessmentInstance',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Select the current NIST guidance or an organization-defined legacy rotation profile.
        [Alias('Profile')][ValidateSet('CurrentNist', 'LegacyRotation')][string] $ConfigurationProfile = 'CurrentNist',
        # Override the profile minimum length; 0 selects 15 (CurrentNist) or 14 (LegacyRotation).
        [ValidateRange(0, 255)][int] $MinimumLength = 0,
        # Minimum history for Microsoft baseline and local policy; this is not a NIST requirement.
        [ValidateRange(0, 255)][int] $MinimumHistory = 24,
        # Maximum age in days under LegacyRotation only.
        [ValidateRange(1, 3650)][int] $MaximumAgeDays = 90,
        # Maximum attempts before account lockout under the Microsoft baseline.
        [ValidateRange(1, 1000)][int] $MaximumLockoutThreshold = 10,
        # Minimum automatic lockout duration; zero means administrator unlock.
        [ValidateRange(1, 10080)][int] $MinimumLockoutMinutes = 15,
        # Minimum minutes before the lockout counter resets.
        [ValidateRange(1, 10080)][int] $MinimumResetMinutes = 15,
        # Confirm complete read access to PSO inventory and computed user resultant policy attributes.
        [bool] $PolicyInventoryReadAccessConfirmed = $false,
        # Engine-provided fixed settings or usage assessment instance.
        $Instance
    )

    $kind = if ($null -eq $Instance) { 'Settings' } else { [string]$Instance.Data.Kind }
    if ($kind -notin @('Settings', 'Usage')) { throw "Unknown FGPP assessment instance '$kind'." }
    $categories = if ($kind -eq 'Usage') { @('FineGrainedPasswordPolicies', 'Users') } else { @('FineGrainedPasswordPolicies') }
    $state = Get-MtADDomainState -Categories $categories
    if ($null -eq $state -or $null -eq $state.FineGrainedPasswordPolicies) {
        throw 'Fine-grained password policy inventory was not returned.'
    }
    $policies = @($state.FineGrainedPasswordPolicies)
    if ($policies.Count -eq 0) {
        if (-not $PolicyInventoryReadAccessConfirmed) {
            Add-MtTestResultDetail -Result "No PSOs were visible for the $kind row. Confirm complete PSO read access before concluding that none exist; confirmation is operator-provided." -Investigate
            return $true
        }
        if ($kind -eq 'Settings') {
            Add-MtTestResultDetail -SkippedBecause NotApplicable
            return $true
        }
        Add-MtTestResultDetail -Result 'No fine-grained password policies were found in the confirmed inventory. Create a PSO and assign it to the intended users or groups.'
        return $false
    }
    if ($kind -eq 'Settings') {
        $lines = [System.Collections.Generic.List[string]]::new()
        $lines.Add('| Policy | DN | Precedence | Setting | Actual | Expected | Status |') | Out-Null
        $lines.Add('| --- | --- | --- | --- | --- | --- | --- |') | Out-Null
        $passed = $true
        foreach ($policy in $policies) {
            if ([string]::IsNullOrWhiteSpace([string]$policy.DistinguishedName) -or
                [string]::IsNullOrWhiteSpace([string]$policy.Name) -or
                $null -eq $policy.PSObject.Properties['MsDsPasswordSettingsPrecedence'] -or
                $null -eq $policy.MsDsPasswordSettingsPrecedence) {
                throw 'A fine-grained password policy is missing its name, DN or precedence.'
            }
            $evaluation = Test-MtAdPasswordPolicyConfiguration -Policy $policy -Profile $ConfigurationProfile -MinimumLength $MinimumLength -MinimumHistory $MinimumHistory -MaximumAgeDays $MaximumAgeDays -MaximumLockoutThreshold $MaximumLockoutThreshold -MinimumLockoutMinutes $MinimumLockoutMinutes -MinimumResetMinutes $MinimumResetMinutes
            if (-not $evaluation.Passed) { $passed = $false }
            foreach ($row in $evaluation.Rows) {
                $lines.Add("| $($policy.Name) | $($policy.DistinguishedName) | $($policy.MsDsPasswordSettingsPrecedence) $($row.Substring(1))") | Out-Null
            }
        }
        $table = $lines -join "`n"
        if (-not $passed) {
            Add-MtTestResultDetail -Result "One or more visible PSOs fail the $ConfigurationProfile security settings. Correct the listed values; this High-severity row does not score inventory or usage.`n`n$table"
            return $false
        }
        Add-MtTestResultDetail -Result "Well done. All $($policies.Count) visible PSOs meet the $ConfigurationProfile security settings assessed here. This does not prove complete NIST compliance or PSO usage.`n`n$table"
        return $true
    }

    if ($null -eq $state.Users) { throw 'User inventory was not returned; effective PSO usage cannot be established.' }
    $usage = Get-MtAdPasswordPolicyUsage -Users @($state.Users) -Policies $policies
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add('| Policy | DN | Precedence | Direct targets | Enabled users receiving PSO | Status |') | Out-Null
    $lines.Add('| --- | --- | --- | --- | --- | --- |') | Out-Null
    $unused = $false
    foreach ($policy in $policies) {
        $count = $usage.Counts[[string]$policy.DistinguishedName]
        $targets = @($policy.MsDsPsoAppliesTo | Where-Object { $null -ne $_ }) -join ', '
        $status = if ($count -gt 0) { 'Used' } else { 'No visible enabled users' }
        if ($count -eq 0) { $unused = $true }
        $lines.Add("| $($policy.Name) | $($policy.DistinguishedName) | $($policy.MsDsPasswordSettingsPrecedence) | $targets | $count | $status |") | Out-Null
    }
    $table = $lines -join "`n"
    if ($usage.EnabledCount -eq 0 -or -not $PolicyInventoryReadAccessConfirmed) {
        Add-MtTestResultDetail -Result "Effective PSO usage cannot be established without visible enabled users and operator-confirmed complete PSO/resultant-policy read access. This Low-severity usage row makes no finding about security settings.`n`n$table" -Investigate
        return $true
    }
    if ($unused) {
        Add-MtTestResultDetail -Result "One or more visible PSOs have no enabled users receiving them. Review direct targets and computed resultant policy precedence. This is Low-severity configuration hygiene, not evidence that password security settings are weak.`n`n$table"
        return $false
    }
    Add-MtTestResultDetail -Result "Well done. All $($policies.Count) visible PSOs are received by enabled users. This does not assess their security settings.`n`n$table"
    return $true
}
