function Test-MtCisSmartLockoutDuration {
    <#
    .SYNOPSIS
        Checks that the smart lockout duration is not shorter than the required minimum.

    .DESCRIPTION
        Checks that the smart lockout duration in Microsoft Entra password protection is at least the minimum number of seconds, so that a locked-out account stays locked long enough to slow down guessing attacks. When the duration is not stored, Microsoft Entra uses its default of 60 seconds.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.9, L1)

    .EXAMPLE
        Test-MtCisSmartLockoutDuration

        Returns true if the lockout duration is at least 60 seconds.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.9
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.9',
        Title = 'Ensure that Account ''Lockout duration in seconds'' is at least 60 seconds',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110.001',
        Control = ('cis-m365:5.2.3.9', 'nist-800-53-r5:AC-7'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Minimum lockout duration in seconds.
        [ValidateRange(1, 86400)]
        [int] $MinimumLockoutDurationInSeconds = 60
    )

    Write-Verbose 'Getting the password rule settings...'
    $groupSettings = Invoke-MtGraphRequest -RelativeUri 'groupSettings'
    $passwordRules = @($groupSettings) | Where-Object { $_.templateId -eq '5cf42378-d67d-4f36-ba46-e8b86229381d' }
    $ruleValues = @{}
    foreach ($rule in $passwordRules.values) {
        $ruleValues[$rule.name] = $rule.value
    }

    # Microsoft's default lockout duration of 60 seconds applies when the setting is not stored.
    $default = 60
    $duration = "$($ruleValues['LockoutDurationInSeconds'])"
    $isStored = $duration -match '^\d+$'
    $effective = if ($isStored) { [int]$duration } else { $default }
    $display = if ($isStored) { $duration } else { "$default (default)" }
    $testResult = $effective -ge $MinimumLockoutDurationInSeconds

    $passText = "The lockout duration is $effective seconds."
    $failText = "The lockout duration is $effective seconds. It should be $MinimumLockoutDurationInSeconds seconds or longer."

    $resultMd = "| Setting | Value (seconds) | Minimum (seconds) | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    $resultMd += "| Lockout duration | $display | $MinimumLockoutDurationInSeconds | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
