function Test-MtCisCustomBannedPasswordList {
    <#
    .SYNOPSIS
        Checks that custom banned passwords are enabled and contain at least one entry.

    .DESCRIPTION
        Checks that the custom banned password list in Microsoft Entra password protection is enabled and has at least one word defined, so that passwords that are likely for your organisation are rejected.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (5.2.3.2, L1)

    .EXAMPLE
        Test-MtCisCustomBannedPasswordList

        Returns true if custom banned passwords are enabled and at least one word is defined.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.5.2.3.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.5.2.3.2',
        Title = 'Ensure custom banned passwords lists are used',
        Product = 'entra',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110.003',
        Control = ('cis-m365:5.2.3.2', 'nist-800-53-r5:IA-5(1)'),
        Service = 'Graph',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting the password rule settings...'
    $groupSettings = Invoke-MtGraphRequest -RelativeUri 'groupSettings' -DisableCache
    $passwordRules = @($groupSettings) | Where-Object { $_.templateId -eq '5cf42378-d67d-4f36-ba46-e8b86229381d' }
    $ruleValues = @{}
    foreach ($rule in $passwordRules.values) {
        $ruleValues[$rule.name] = $rule.value
    }

    $bannedList = "$($ruleValues['BannedPasswordList'])"
    $bannedCount = @($bannedList -split '\s+' | Where-Object { $_ }).Count
    $enabled = "$($ruleValues['EnableBannedPasswordCheck'])"

    $checks = @(
        [pscustomobject]@{ Setting = 'Enforce custom list'; Value = $(if ($enabled) { $enabled } else { 'Not found' }); Pass = $enabled -eq 'True' }
        [pscustomobject]@{ Setting = 'Custom banned password count'; Value = "$bannedCount"; Pass = $bannedCount -gt 0 }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'Custom banned passwords are enabled and the list contains at least one word.'
    $failText = 'Custom banned passwords are not enabled or the list is empty.'
    $resultMd = "| Setting | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($check in $checks) {
        $resultMd += "| $($check.Setting) | $($check.Value) | $(if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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
