function Test-MtCisSafeAttachment {
    <#
    .SYNOPSIS
    Checks if the Safe Attachments policy is enabled

    .DESCRIPTION
    The Safe Attachments policy is enabled
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.4, L2)

    .EXAMPLE
    Test-MtCisSafeAttachment

    Returns true safe attachments policy is enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisSafeAttachment
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.4',
        Title = 'Ensure the highest-priority Safe Attachments policy is enabled',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'safe-attachments',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566.001', 'T1204.002'),
        Control = ('cis-m365:2.1.4', 'nist-800-53-r5:SI-3'),
        Service = ('ExchangeOnline', 'Graph', 'SecurityCompliance'),
        License = 'ATP_ENTERPRISE',
        Author = 'NZLostboy',
        Contributor = ('weyCC81', 'thomas-s-schmidt')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting Safe Attachment policies and rules...'
    $policies = @(Get-MtExo -Request SafeAttachmentPolicy)
    $presetRules = @(Get-MtExo -Request ATPProtectionPolicyRule)
    $customRules = @(Get-MtExo -Request SafeAttachmentRule)
    $builtInRules = @(Get-MtExo -Request ATPBuiltInProtectionRule)

    $strictRules = @($presetRules | Where-Object { $_.Identity -eq 'Strict Preset Security Policy' -and $_.State -eq 'Enabled' })
    $standardRules = @($presetRules | Where-Object { $_.Identity -eq 'Standard Preset Security Policy' -and $_.State -eq 'Enabled' })
    $selectedRule = $null
    $selectedRuleType = $null
    $policyCandidates = @()

    if ($strictRules.Count -gt 0) {
        $selectedRule = $strictRules[0]
        $selectedRuleType = 'Strict preset'
        $policyCandidates = @($policies | Where-Object { $_.RecommendedPolicyType -eq 'Strict' })
    } elseif ($standardRules.Count -gt 0) {
        $selectedRule = $standardRules[0]
        $selectedRuleType = 'Standard preset'
        $policyCandidates = @($policies | Where-Object { $_.RecommendedPolicyType -eq 'Standard' })
    } else {
        $enabledCustomRules = @($customRules | Where-Object { $_.State -eq 'Enabled' } | Sort-Object { [int]$_.Priority })
        if ($enabledCustomRules.Count -gt 0) {
            $selectedRule = $enabledCustomRules[0]
            $selectedRuleType = 'custom'
            $rulePolicy = $selectedRule.SafeAttachmentPolicy
            $policyCandidates = @($policies | Where-Object {
                    $_.Name -eq $rulePolicy -or $_.Identity -eq $rulePolicy -or $_.Id -eq $rulePolicy
                })
        } else {
            $enabledBuiltInRules = @($builtInRules | Where-Object { $_.State -eq 'Enabled' })
            if ($enabledBuiltInRules.Count -gt 0) {
                $selectedRule = $enabledBuiltInRules[0]
                $selectedRuleType = 'built-in protection'
                $policyCandidates = @($policies | Where-Object {
                        $_.IsBuiltInProtection -eq $true -or $_.Name -eq 'Built-In Protection Policy'
                    })
            }
        }
    }

    if ($null -eq $selectedRule) {
        Add-MtTestResultDetail -Result 'No enabled Safe Attachments rule was returned; the highest-priority policy could not be determined.'
        return $false
    }
    if ($policyCandidates.Count -ne 1) {
        Add-MtTestResultDetail -Result "Expected one policy for the selected $selectedRuleType rule '$($selectedRule.Identity)', found $($policyCandidates.Count)."
        return $false
    }

    $policy = $policyCandidates[0]
    $domainTargets = @($selectedRule.RecipientDomainIs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $groupTargets = @($selectedRule.SentToMemberOf | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $userTargets = @($selectedRule.SentTo | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
    $recipientConditions = @($domainTargets + $groupTargets + $userTargets)
    $recipientExceptions = @(
        $selectedRule.ExceptIfRecipientDomainIs
        $selectedRule.ExceptIfSentToMemberOf
        $selectedRule.ExceptIfSentTo
    ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
    $acceptedDomains = @()
    if ($domainTargets.Count -gt 0) {
        $acceptedDomains = @(Get-MtExo -Request AcceptedDomain | ForEach-Object { $_.Name })
    }
    $domainsCoverTenant = $acceptedDomains.Count -gt 0 -and @($acceptedDomains | Where-Object { $_ -notin $domainTargets }).Count -eq 0
    $scopePass = $recipientConditions.Count -eq 0 -or $domainsCoverTenant -or $groupTargets.Count -gt 0
    $scopeDescription = if ($recipientConditions.Count -eq 0) { 'All recipients' } else { $recipientConditions -join ', ' }
    if ($recipientExceptions.Count -gt 0) {
        $scopeDescription += "; exclusions: $($recipientExceptions -join ', ')"
    }

    $safeAttachmentCheckList = @(
        [pscustomobject]@{ CheckName = 'Enable'; Value = $policy.Enable; Pass = $policy.Enable -eq $true }
        [pscustomobject]@{ CheckName = 'Action'; Value = $policy.Action; Pass = $policy.Action -eq 'Block' }
        [pscustomobject]@{ CheckName = 'QuarantineTag'; Value = $policy.QuarantineTag; Pass = $policy.QuarantineTag -eq 'AdminOnlyAccessPolicy' }
        [pscustomobject]@{ CheckName = 'Rule state'; Value = $selectedRule.State; Pass = $selectedRule.State -eq 'Enabled' }
        [pscustomobject]@{ CheckName = 'Rule scope'; Value = $scopeDescription; Pass = $scopePass }
    )
    $testResult = @($safeAttachmentCheckList | Where-Object { -not $_.Pass }).Count -eq 0

    $portalLink = 'https://security.microsoft.com/safeattachmentv2'
    if ($testResult) {
        $testResultMarkdown = "Well done. The highest-priority Safe Attachments policy '$($policy.Name)' and its rule match CIS recommendations ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "The highest-priority Safe Attachments policy '$($policy.Name)' or its rule does not match CIS recommendations ($portalLink).`n`n%TestResult%"
    }

    $resultMd = "| Check Name | Value | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($item in $safeAttachmentCheckList) {
        $itemResult = if ($item.Pass) { '✅ Pass' } else { '❌ Fail' }
        $value = if ($null -eq $item.Value) { 'Not returned' } else { @($item.Value) -join ', ' }
        $resultMd += "| $($item.CheckName) | $value | $itemResult |`n"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd
    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
