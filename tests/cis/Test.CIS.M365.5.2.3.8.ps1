function Test-MtCisSmartLockoutThreshold {
    <#
    .SYNOPSIS
        Checks that the smart lockout threshold is not greater than the allowed maximum.

    .DESCRIPTION
        Checks that the smart lockout threshold in Microsoft Entra password protection does not exceed the maximum, which limits how many wrong passwords an attacker can try before the account is locked out. When the threshold is not stored, Microsoft Entra uses its public cloud default of 10.
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
        [int] $MaximumLockoutThreshold = 10
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
    $testResult = $effective -le $MaximumLockoutThreshold

    $passText = "The lockout threshold is $effective."
    $failText = "The lockout threshold is $effective. It should be $MaximumLockoutThreshold or less."

    $resultMd = "| Setting | Value | Maximum | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    $resultMd += "| Lockout threshold | $display | $MaximumLockoutThreshold | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
