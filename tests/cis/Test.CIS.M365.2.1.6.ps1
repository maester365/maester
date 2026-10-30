function Test-MtCisOutboundSpamFilterPolicy {
    <#
    .SYNOPSIS
    Checks if Exchange Online Spam Policies are set to notify administrators

    .DESCRIPTION
    Ensure Exchange Online Spam Policies are set to notify administrators
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.6, L1)

    .EXAMPLE
    Test-MtCisOutboundSpamFilterPolicy

    Returns true if Exchange Online Spam Policies are set to notify administrators

    .LINK
    https://maester.dev/docs/commands/Test-MtCisOutboundSpamFilterPolicy
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.6',
        Title = 'Ensure Exchange Online Spam Policies are set to notify administrators',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('cis-m365:2.1.6', 'nist-800-53-r5:SI-4(5)'),
        Service = ('ExchangeOnline', 'SecurityCompliance'),
        Author = 'NZLostboy',
        Contributor = 'thomas-s-schmidt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting outbound spam policies and rules...'
    $policies = @(Get-MtExo -Request HostedOutboundSpamFilterPolicy)
    $customPolicies = @($policies | Where-Object { $_.IsDefault -ne $true })
    $enabledRules = @(Get-MtExo -Request HostedOutboundSpamFilterRule | Where-Object { $_.State -eq 'Enabled' })
    $orderedEnabledRules = @($enabledRules | Sort-Object { [int]$_.Priority })

    $selectedRule = $null
    if ($orderedEnabledRules.Count -gt 0) {
        $selectedRule = $orderedEnabledRules[0]
        $rulePolicy = [string]$selectedRule.HostedOutboundSpamFilterPolicy
        $selectedPolicies = @($customPolicies | Where-Object { $_.Name -eq $rulePolicy -or $_.Identity -eq $rulePolicy -or $_.Id -eq $rulePolicy })
        if ($selectedPolicies.Count -ne 1) {
            Add-MtTestResultDetail -Result "Expected one policy for the highest-priority enabled outbound spam rule '$($selectedRule.Name)', found $($selectedPolicies.Count)."
            return $false
        }
        $policy = $selectedPolicies[0]
        $policySelection = 'highest-priority enabled custom policy'
    } else {
        $defaultPolicies = @($policies | Where-Object { $_.IsDefault -eq $true })
        if ($defaultPolicies.Count -ne 1) {
            Add-MtTestResultDetail -Result "Expected one default outbound spam policy when no enabled custom rule applies, found $($defaultPolicies.Count)."
            return $false
        }
        $policy = $defaultPolicies[0]
        $policySelection = 'default policy'
    }

    $policyName = if ($policy.Name) { $policy.Name } else { $policy.Identity }
    $ruleDescription = if ($selectedRule) { "Rule '$($selectedRule.Name)' (priority $($selectedRule.Priority))" } else { 'Default policy' }
    $bccRecipients = @($policy.BccSuspiciousOutboundAdditionalRecipients | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $notificationRecipients = @($policy.NotifyOutboundSpamRecipients | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $checks = @(
        [pscustomobject]@{ CheckName = 'BccSuspiciousOutboundMail'; Value = $policy.BccSuspiciousOutboundMail; Pass = $policy.BccSuspiciousOutboundMail -eq $true }
        [pscustomobject]@{ CheckName = 'BccSuspiciousOutboundAdditionalRecipients'; Value = if ($bccRecipients.Count -gt 0) { $bccRecipients -join ', ' } else { 'Not set' }; Pass = $bccRecipients.Count -gt 0 }
        [pscustomobject]@{ CheckName = 'NotifyOutboundSpam'; Value = $policy.NotifyOutboundSpam; Pass = $policy.NotifyOutboundSpam -eq $true }
        [pscustomobject]@{ CheckName = 'NotifyOutboundSpamRecipients'; Value = if ($notificationRecipients.Count -gt 0) { $notificationRecipients -join ', ' } else { 'Not set' }; Pass = $notificationRecipients.Count -gt 0 }
    )
    $testResult = @($checks | Where-Object { -not $_.Pass }).Count -eq 0
    $portalLink = 'https://security.microsoft.com/antispam'

    if ($testResult) {
        $testResultMarkdown = "Well done. The $policySelection '$policyName' is configured to notify administrators ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The $policySelection '$policyName' is not configured to notify administrators as required ($portalLink).`n`n%TestResult%"
    }

    $resultMd = "| Policy | Rule | Setting | Current Value | Result |`n"
    $resultMd += "| --- | --- | --- | --- | --- |`n"
    foreach ($check in $checks) {
        $itemResult = if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }
        $resultMd += "| $policyName | $ruleDescription | $($check.CheckName) | $($check.Value) | $itemResult |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
