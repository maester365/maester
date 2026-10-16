function Test-MtCisStrictPresetForPriorityAccounts {
    <#
    .SYNOPSIS
        Checks that the Strict preset security policy is enabled and has recipients.

    .DESCRIPTION
        Checks that both the Exchange Online Protection and the Defender for Office 365 rules of the Strict preset security policy are enabled and apply to at least one recipient, so that priority accounts have the strictest protection.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.2, L1)

    .EXAMPLE
        Test-MtCisStrictPresetForPriorityAccounts

        Returns true if the Strict preset security policy is enabled and has recipients.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.2.4.2
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.4.2',
        Title = 'Ensure Priority accounts have ''Strict protection'' presets applied',
        Product = 'defender',
        Feature = 'tenant-settings',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566',
        Control = ('cis-m365:2.4.2', 'nist-800-53-r5:SI-4(5)'),
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting preset security policy rules...'
    $eopRule = @(Get-MtExo -Request EOPProtectionPolicyRule) | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' } | Select-Object -First 1
    $atpRule = @(Get-MtExo -Request ATPProtectionPolicyRule) | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' } | Select-Object -First 1

    $report = foreach ($entry in @(@{ Name = 'Exchange Online Protection'; Rule = $eopRule }, @{ Name = 'Defender for Office 365'; Rule = $atpRule })) {
        $rule = $entry.Rule
        $hasTargets = @($rule.SentTo).Count -gt 0 -or @($rule.SentToMemberOf).Count -gt 0 -or @($rule.RecipientDomainIs).Count -gt 0
        [pscustomobject]@{
            Component = $entry.Name
            State = if ($rule) { $rule.State } else { 'Not found' }
            Targets = $hasTargets
            Pass = $null -ne $rule -and $rule.State -eq 'Enabled' -and $hasTargets
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The Strict preset security policy is enabled and applied to recipients.'
    $failText = 'The Strict preset security policy is not enabled, or it has no recipients.'

    $resultMd = "| Component | Rule state | Has recipients | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Component) | $($row.State) | $($row.Targets) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
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