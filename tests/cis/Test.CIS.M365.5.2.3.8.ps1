function Test-MtCisSmartLockoutThreshold {
    <#
    .SYNOPSIS
        Checks that the smart lockout threshold is not greater than the allowed maximum.

    .DESCRIPTION
        Checks that the smart lockout threshold in Microsoft Entra password protection does not exceed the maximum, which limits how many wrong passwords an attacker can try before the account is locked out. When the threshold is not stored, Microsoft Entra uses its public cloud default of 10.
        With MinimumLockoutDurationSeconds it also checks that an account stays locked for at least that long. When the duration is not stored, Microsoft Entra uses its default of 60 seconds. CIS does not ask for a duration, so it is not checked by default.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.8, L1)

    .EXAMPLE
        Test-MtCisSmartLockoutThreshold

        Returns true if the lockout threshold is at most 10.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.8
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.8',
        Title = 'Ensure that Account ''Lockout threshold'' is ''10'' or less',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1110.001', 'T1110.003'),
        Control = ('cis-m365:5.2.3.8', 'nist-800-53-r5:AC-7'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum number of failed sign-ins before the account is locked out.
        [ValidateRange(1, 50)]
        [int] $MaximumLockoutThreshold = 10,

        # Shortest lockout duration, in seconds, that is allowed. 0 does not check the duration.
        [ValidateRange(0, 86400)]
        [int] $MinimumLockoutDurationSeconds = 0
    )

    Write-Verbose 'Getting the password rule settings...'
    $groupSettings = Invoke-MtGraphRequest -RelativeUri 'groupSettings'
    $passwordRules = @($groupSettings) | Where-Object { $_.templateId -eq '5cf42378-d67d-4f36-ba46-e8b86229381d' }
    $ruleValues = @{}
    foreach ($rule in $passwordRules.values) {
        $ruleValues[$rule.name] = $rule.value
    }

    # Microsoft's default lockout threshold applies when the setting is not stored.
    $default = 10
    $threshold = "$($ruleValues['LockoutThreshold'])"
    $isStored = $threshold -match '^\d+$'
    $effective = if ($isStored) { [int]$threshold } else { $default }
    $display = if ($isStored) { $threshold } else { "$default (default)" }
    $thresholdOk = $effective -le $MaximumLockoutThreshold

    # Microsoft's default lockout duration applies when the setting is not stored.
    $defaultDuration = 60
    $duration = "$($ruleValues['LockoutDurationInSeconds'])"
    $isDurationStored = $duration -match '^\d+$'
    $effectiveDuration = if ($isDurationStored) { [int]$duration } else { $defaultDuration }
    $durationDisplay = if ($isDurationStored) { $duration } else { "$defaultDuration (default)" }
    $durationOk = $MinimumLockoutDurationSeconds -eq 0 -or $effectiveDuration -ge $MinimumLockoutDurationSeconds
    $testResult = $thresholdOk -and $durationOk

    $passText = "The lockout threshold is $effective."
    $failText = if (-not $thresholdOk) { "The lockout threshold is $effective. It should be $MaximumLockoutThreshold or less." } else { '' }
    if ($MinimumLockoutDurationSeconds -gt 0) {
        $passText += " Accounts stay locked for $effectiveDuration seconds."
        if (-not $durationOk) { $failText = "$failText Accounts stay locked for $effectiveDuration seconds. It should be $MinimumLockoutDurationSeconds seconds or more.".Trim() }
    }

    $resultMd = "| Setting | Value | Required | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    $resultMd += "| Lockout threshold | $display | $MaximumLockoutThreshold or less | $(if ($thresholdOk) { '✅ Pass' } else { '❌ Fail' }) |`n"
    if ($MinimumLockoutDurationSeconds -gt 0) {
        $resultMd += "| Lockout duration (seconds) | $durationDisplay | $MinimumLockoutDurationSeconds or more | $(if ($durationOk) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
