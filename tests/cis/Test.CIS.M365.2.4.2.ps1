function Test-MtCisStrictPresetForPriorityAccount {
    <#
    .SYNOPSIS
        Checks that both Strict preset security policy rules are enabled and have recipient conditions.

    .DESCRIPTION
        Checks that the Exchange Online Protection and Defender for Office 365 rules of the Strict preset security policy are enabled and have at least one recipient condition (SentTo, SentToMemberOf or RecipientDomainIs), as required by the CIS PowerShell audit procedure.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.4.2, L1)

    .EXAMPLE
        Test-MtCisStrictPresetForPriorityAccount

        Returns true if both Strict preset security policy rules are enabled and have recipient conditions.

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

    Write-Verbose 'Getting Strict preset security policy rules...'
    $eopRule = @(Get-MtExo -Request EOPProtectionPolicyRule) | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' } | Select-Object -First 1
    $atpRule = @(Get-MtExo -Request ATPProtectionPolicyRule) | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' } | Select-Object -First 1
    $rules = @(
        [pscustomobject]@{ Name = 'Exchange Online Protection'; Rule = $eopRule }
        [pscustomobject]@{ Name = 'Defender for Office 365'; Rule = $atpRule }
    )
    $report = foreach ($entry in $rules) {
        $rule = $entry.Rule
        $recipientConditions = @()
        if ($rule) {
            foreach ($condition in @('SentTo', 'SentToMemberOf', 'RecipientDomainIs')) {
                if (@($rule.$condition | Where-Object { $_ }).Count -gt 0) {
                    $recipientConditions += $condition
                }
            }
        }
        $state = if ($rule) { $rule.State } else { 'Not found' }
        [pscustomobject]@{
            Component           = $entry.Name
            State               = $state
            RecipientConditions = if ($recipientConditions.Count -gt 0) { $recipientConditions -join ', ' } else { 'None' }
            Pass                = $null -ne $rule -and $state -eq 'Enabled' -and $recipientConditions.Count -gt 0
        }
    }
    $testResult = @($report | Where-Object { -not $_.Pass }).Count -eq 0

    $resultMd = "| Component | Rule state | Recipient conditions | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($row in $report) {
        $resultMd += "| $($row.Component) | $($row.State) | $($row.RecipientConditions) | $(if ($row.Pass) { '✅ Pass' } else { '❌ Fail' }) |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. Both Strict preset security policy rules are enabled and have recipient conditions.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "One or both Strict preset security policy rules are missing, disabled, or have no recipient conditions. Configure both rules with a recipient target using SentTo, SentToMemberOf or RecipientDomainIs.`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
