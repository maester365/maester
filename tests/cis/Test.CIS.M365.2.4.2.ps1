function Test-MtCisStrictPresetForPriorityAccount {
    <#
    .SYNOPSIS
        Checks that both Strict preset security policy rules are enabled and have an explicit recipient condition.

    .DESCRIPTION
        Checks that both the Exchange Online Protection and the Defender for Office 365 rules of the Strict preset security policy are enabled and have at least one explicit recipient condition. A rule with no recipient conditions applies to all recipients, including priority accounts, but this test follows the CIS PowerShell audit procedure literally and requires an explicit condition to pass. It does not verify that the selected recipients are priority accounts; add a priority-account group to SentToMemberOf.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.2, L1)

    .EXAMPLE
        Test-MtCisStrictPresetForPriorityAccount

        Returns true if both Strict preset security policy rules are enabled and have an explicit recipient condition.

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
        $hasTargets = @($rule.SentTo | Where-Object { $_ }).Count -gt 0 -or @($rule.SentToMemberOf | Where-Object { $_ }).Count -gt 0 -or @($rule.RecipientDomainIs | Where-Object { $_ }).Count -gt 0
        $scope = if (-not $rule) { 'Rule not found' } elseif ($hasTargets) { 'Explicit recipient condition' } else { 'All recipients (no conditions)' }
        [pscustomobject]@{
            Component = $entry.Name
            State = if ($rule) { $rule.State } else { 'Not found' }
            Scope = $scope
            Pass = $null -ne $rule -and $rule.State -eq 'Enabled' -and $hasTargets
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $passText = 'The Strict preset security policy is enabled and applied to recipients.'
    $failText = 'The Strict preset security policy is missing or disabled, or one or more rules lack the explicit recipient condition required by the CIS audit.'
    $scopeNote = if (@($report | Where-Object { $_.Scope -eq 'All recipients (no conditions)' }).Count -gt 0) {
        "`n`nNote: When enabled, a rule with no recipient conditions applies to everyone, including priority accounts. The CIS 2.4.2 PowerShell audit requires an explicit recipient condition to pass. Add a group containing priority accounts to SentToMemberOf to meet that criterion.`n`n"
    } else {
        ''
    }

    $resultMd = "| Component | Rule state | Scope | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Component) | $($row.State) | $($row.Scope) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText$scopeNote`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
