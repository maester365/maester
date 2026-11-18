function Test-MtAdPasswordPolicyConfiguration {
    <#
    .SYNOPSIS
    Evaluates normalized default-domain or fine-grained password policy fields.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] $Policy,
        [Alias('Profile')][ValidateSet('CurrentNist', 'LegacyRotation')][string] $ConfigurationProfile = 'CurrentNist',
        [ValidateRange(0, 255)][int] $MinimumLength = 0,
        [ValidateRange(0, 255)][int] $MinimumHistory = 24,
        [ValidateRange(1, 3650)][int] $MaximumAgeDays = 90,
        [ValidateRange(1, 1000)][int] $MaximumLockoutThreshold = 10,
        [ValidateRange(1, 10080)][int] $MinimumLockoutMinutes = 15,
        [ValidateRange(1, 10080)][int] $MinimumResetMinutes = 15,
        [string[]] $Fields = @('PwdHistoryLength', 'MaxPwdAge', 'MinPwdAge', 'MinPwdLength', 'ComplexityEnabled', 'ReversibleEncryptionEnabled', 'LockoutDuration', 'LockoutThreshold', 'LockoutObservationWindow')
    )

    if ($null -eq $Policy) { throw 'Password policy data is missing.' }
    $expectedLength = if ($MinimumLength -eq 0) { if ($ConfigurationProfile -eq 'CurrentNist') { 15 } else { 14 } } else { $MinimumLength }
    $rows = [System.Collections.Generic.List[string]]::new()
    $passed = $true
    $investigate = $false
    foreach ($field in $Fields) {
        $property = $Policy.PSObject.Properties[$field]
        if ($null -eq $property -or $null -eq $property.Value) {
            throw "Password policy field '$field' is missing; cannot evaluate it."
        }
        $value = $property.Value
        $status = 'Pass'
        $expected = ''
        switch ($field) {
            'PwdHistoryLength' {
                $expected = "At least $MinimumHistory (Microsoft baseline; not a NIST requirement)"
                if ([int]$value -lt $MinimumHistory) { $status = 'Fail' }
            }
            'MinPwdLength' {
                $expected = "At least $expectedLength characters"
                if ([int]$value -lt $expectedLength) { $status = 'Fail' }
            }
            'MaxPwdAge' {
                if ($value -isnot [timespan]) { throw "Password policy field '$field' must be a TimeSpan." }
                $days = [math]::Abs($value.TotalDays)
                $value = "$days days"
                if ($ConfigurationProfile -eq 'CurrentNist') {
                    $expected = '0 days (no forced periodic expiration)'
                    if ($days -ne 0) { $status = 'Fail' }
                } else {
                    $expected = "1 to $MaximumAgeDays days (organization-selected legacy rotation)"
                    if ($days -eq 0 -or $days -gt $MaximumAgeDays) { $status = 'Fail' }
                }
            }
            'MinPwdAge' {
                if ($value -isnot [timespan]) { throw "Password policy field '$field' must be a TimeSpan." }
                $value = "$([math]::Abs($value.TotalDays)) days"
                $expected = 'Observation only; not a password strength or rotation requirement'
                $status = 'Observe'
            }
            'ComplexityEnabled' {
                if ($value -isnot [bool]) { throw "Password policy field '$field' must be a Boolean." }
                $expected = if ($ConfigurationProfile -eq 'CurrentNist') { 'Observation only; verify blocklist before changing composition rules' } else { 'Enabled (legacy profile)' }
                if ($ConfigurationProfile -eq 'CurrentNist') { $status = 'Observe' } elseif (-not $value) { $status = 'Fail' }
            }
            'ReversibleEncryptionEnabled' {
                if ($value -isnot [bool]) { throw "Password policy field '$field' must be a Boolean." }
                $expected = 'Disabled'
                if ($value) { $status = 'Fail' }
            }
            'LockoutThreshold' {
                $expected = "1 to $MaximumLockoutThreshold attempts (Microsoft baseline, not NIST 100-attempt ceiling)"
                if ([int]$value -lt 1 -or [int]$value -gt $MaximumLockoutThreshold) { $status = 'Fail' }
            }
            'LockoutDuration' {
                if ($value -isnot [timespan]) { throw "Password policy field '$field' must be a TimeSpan." }
                $minutes = [math]::Abs($value.TotalMinutes)
                $value = if ($minutes -eq 0) { '0 (until administrator unlocks)' } else { "$minutes minutes" }
                $expected = "0 (manual unlock) or at least $MinimumLockoutMinutes minutes"
                if ($minutes -ne 0 -and $minutes -lt $MinimumLockoutMinutes) { $status = 'Fail' }
            }
            'LockoutObservationWindow' {
                if ($value -isnot [timespan]) { throw "Password policy field '$field' must be a TimeSpan." }
                $minutes = [math]::Abs($value.TotalMinutes)
                $value = "$minutes minutes"
                $expected = "At least $MinimumResetMinutes minutes"
                if ($minutes -lt $MinimumResetMinutes) { $status = 'Fail' }
            }
            default { throw "Unsupported password policy field '$field'." }
        }
        if ($status -eq 'Fail') { $passed = $false }
        $rows.Add("| $field | $value | $expected | $status |") | Out-Null
    }
    return [pscustomobject]@{ Passed = $passed; Investigate = $investigate; Rows = @($rows); Profile = $ConfigurationProfile }
}
