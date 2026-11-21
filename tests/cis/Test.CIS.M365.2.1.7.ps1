function Test-MtCisSafeAntiPhishingPolicy {
    <#
    .SYNOPSIS
    Checks if the anti-phishing policy matches CIS recommendations

    .DESCRIPTION
    Evaluates anti-phishing policies and their highest-priority enabled matching rules. It checks enabled status, phishing threshold, targeted user and organization domain protection, mailbox intelligence and spoof protection, quarantine actions, safety tips, DMARC handling, and recipient scope. The test passes when at least one returned policy meets all checked criteria; it does not require every returned policy to pass.
    CIS Microsoft 365 Foundations Benchmark v7.0.0 (2.1.7, L1)

    .EXAMPLE
    Test-MtCisSafeAntiPhishingPolicy

    Returns true if at least one anti-phishing policy and its highest-priority enabled matching rule meet all CIS checks. Recipient scope passes with no targets, coverage of every accepted domain, or at least one group target, when the rule names no users; group membership and exclusions are not validated. When no policy passes and a policy fails only on a rule that adds users to every accepted domain or to a group, the result is Investigate: the scope depends on whether the rule matches all or any of its conditions, which the rule does not show (MC1546447). Users alone, or users with only some accepted domains, fail.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisSafeAntiPhishingPolicy
    #>
    [MaesterTest(
        Id = 'CIS.M365.2.1.7',
        Title = 'Ensure that an anti-phishing policy has been created',
        Product = 'defender',
        RelatedProduct = 'exchange',
        Feature = 'anti-phishing',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.001', 'T1684.002'),
        Control = ('cis-m365:2.1.7', 'nist-800-53-r5:SI-8'),
        Service = ('ExchangeOnline', 'Graph'),
        License = 'ATP_ENTERPRISE',
        Author = 'NZLostboy',
        Contributor = ('thomas-s-schmidt', 'Mynster9361')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting anti-phishing policies and rules...'
    $policies = @(Get-MtExo -Request AntiPhishPolicy)
    $rules = @(Get-MtExo -Request AntiPhishRule)
    if ($policies.Count -eq 0) {
        Add-MtTestResultDetail -Result 'No anti-phishing policies were returned; compliance could not be established.'
        return $false
    }

    $acceptedDomains = @(Get-MtExo -Request AcceptedDomain | ForEach-Object { $_.Name })
    $policyReports = foreach ($policy in $policies) {
        $policyNames = @($policy.Name, $policy.Identity) | Where-Object { $_ }
        $matchingRules = @($rules | Where-Object { $_.AntiPhishPolicy -in $policyNames })
        $enabledRules = @($matchingRules | Where-Object { $_.State -eq 'Enabled' } | Sort-Object { [int]$_.Priority })
        $rule = if ($enabledRules.Count -gt 0) { $enabledRules[0] } else { $null }

        $domainTargets = @($rule.RecipientDomainIs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $groupTargets = @($rule.SentToMemberOf | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $userTargets = @($rule.SentTo | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $recipientConditions = @($domainTargets + $groupTargets + $userTargets)
        $domainScopeCoversTenant = $domainTargets.Count -gt 0 -and $acceptedDomains.Count -gt 0 -and @($acceptedDomains | Where-Object { $_ -notin $domainTargets }).Count -eq 0
        # Users, groups and domains are different condition types. A rule that matches all of them (AND, the logic of existing
        # rules) applies only to the listed users. Rules created or edited after the MC1546447 rollout match any of them (OR),
        # and the rule does not expose which logic applies, so users added to domain or group targets need investigation.
        $scopeDependsOnMatchLogic = $null -ne $rule -and $userTargets.Count -gt 0 -and ($domainScopeCoversTenant -or $groupTargets.Count -gt 0)
        $scopePass = $null -ne $rule -and $userTargets.Count -eq 0 -and ($recipientConditions.Count -eq 0 -or $domainScopeCoversTenant -or $groupTargets.Count -gt 0)
        $scopeDescription = if ($null -eq $rule) {
            'No enabled matching rule'
        } elseif ($recipientConditions.Count -eq 0) {
            'All recipients'
        } else {
            $recipientConditions -join ', '
        }
        if ($scopeDependsOnMatchLogic) {
            $scopeDescription += ' (only these users if the rule matches all conditions)'
        }
        $recipientExceptions = @(
            $rule.ExceptIfRecipientDomainIs
            $rule.ExceptIfSentToMemberOf
            $rule.ExceptIfSentTo
        ) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }
        if ($recipientExceptions.Count -gt 0) {
            $scopeDescription += "; exclusions: $($recipientExceptions -join ', ')"
        }

        $targetedUsers = @($policy.TargetedUsersToProtect | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $targetedUsersValue = if ($targetedUsers.Count -eq 0) { 'Not set' } else { "$($targetedUsers.Count) configured" }
        $ruleValue = if ($null -eq $rule) { 'Not found or disabled' } else { "$($rule.State): $scopeDescription" }
        $checks = @(
            [pscustomobject]@{ CheckName = 'Enabled'; Value = $policy.Enabled; Pass = $policy.Enabled -eq $true }
            [pscustomobject]@{ CheckName = 'PhishThresholdLevel'; Value = $policy.PhishThresholdLevel; Pass = $policy.PhishThresholdLevel -ge 3 }
            [pscustomobject]@{ CheckName = 'EnableTargetedUserProtection'; Value = $policy.EnableTargetedUserProtection; Pass = $policy.EnableTargetedUserProtection -eq $true }
            [pscustomobject]@{ CheckName = 'TargetedUsersToProtect'; Value = $targetedUsersValue; Pass = $targetedUsers.Count -gt 0 -and $targetedUsers.Count -le 350 }
            [pscustomobject]@{ CheckName = 'EnableOrganizationDomainsProtection'; Value = $policy.EnableOrganizationDomainsProtection; Pass = $policy.EnableOrganizationDomainsProtection -eq $true }
            [pscustomobject]@{ CheckName = 'EnableMailboxIntelligence'; Value = $policy.EnableMailboxIntelligence; Pass = $policy.EnableMailboxIntelligence -eq $true }
            [pscustomobject]@{ CheckName = 'EnableMailboxIntelligenceProtection'; Value = $policy.EnableMailboxIntelligenceProtection; Pass = $policy.EnableMailboxIntelligenceProtection -eq $true }
            [pscustomobject]@{ CheckName = 'EnableSpoofIntelligence'; Value = $policy.EnableSpoofIntelligence; Pass = $policy.EnableSpoofIntelligence -eq $true }
            [pscustomobject]@{ CheckName = 'TargetedUserProtectionAction'; Value = $policy.TargetedUserProtectionAction; Pass = $policy.TargetedUserProtectionAction -eq 'Quarantine' }
            [pscustomobject]@{ CheckName = 'TargetedDomainProtectionAction'; Value = $policy.TargetedDomainProtectionAction; Pass = $policy.TargetedDomainProtectionAction -eq 'Quarantine' }
            [pscustomobject]@{ CheckName = 'MailboxIntelligenceProtectionAction'; Value = $policy.MailboxIntelligenceProtectionAction; Pass = $policy.MailboxIntelligenceProtectionAction -eq 'Quarantine' }
            [pscustomobject]@{ CheckName = 'EnableFirstContactSafetyTips'; Value = $policy.EnableFirstContactSafetyTips; Pass = $policy.EnableFirstContactSafetyTips -eq $true }
            [pscustomobject]@{ CheckName = 'EnableSimilarUsersSafetyTips'; Value = $policy.EnableSimilarUsersSafetyTips; Pass = $policy.EnableSimilarUsersSafetyTips -eq $true }
            [pscustomobject]@{ CheckName = 'EnableSimilarDomainsSafetyTips'; Value = $policy.EnableSimilarDomainsSafetyTips; Pass = $policy.EnableSimilarDomainsSafetyTips -eq $true }
            [pscustomobject]@{ CheckName = 'EnableUnusualCharactersSafetyTips'; Value = $policy.EnableUnusualCharactersSafetyTips; Pass = $policy.EnableUnusualCharactersSafetyTips -eq $true }
            [pscustomobject]@{ CheckName = 'HonorDmarcPolicy'; Value = $policy.HonorDmarcPolicy; Pass = $policy.HonorDmarcPolicy -eq $true }
            [pscustomobject]@{ CheckName = 'Enabled matching rule and scope'; Value = $ruleValue; Pass = $scopePass }
        )

        [pscustomobject]@{
            Name = $policy.Name
            Checks = $checks
            Pass = @($checks | Where-Object { -not $_.Pass }).Count -eq 0
            Investigate = $scopeDependsOnMatchLogic -and @($checks | Where-Object { -not $_.Pass }).Count -eq 1
        }
    }

    $testResult = @($policyReports | Where-Object { $_.Pass }).Count -gt 0
    $investigatePolicies = @(if (-not $testResult) { $policyReports | Where-Object { $_.Investigate } })
    $portalLink = 'https://security.microsoft.com/antiphishing'
    if ($testResult) {
        $testResultMarkdown = "Well done. An enabled anti-phishing policy and matching rule meet CIS recommendations ($portalLink).`n`n%TestResult%"
    } elseif ($investigatePolicies.Count -gt 0) {
        $testResultMarkdown = "Anti-phishing policy '$($investigatePolicies.Name -join "', '")' meets the other CIS recommendations, but its rule adds users to domain or group targets. If the rule matches all conditions, as rules created before the MC1546447 rollout do until they are edited, it applies only to those users. If it matches any condition, it also covers the domains or groups. The rule does not show which logic applies, so move the users to a separate policy to make the scope explicit ($portalLink).`n`n%TestResult%"
    } else {
        $testResultMarkdown = "No enabled anti-phishing policy and matching rule meet all CIS recommendations ($portalLink).`n`n%TestResult%"
    }

    $resultMd = "| Policy | Check Name | Value | Result |`n"
    $resultMd += "| --- | --- | --- | --- |`n"
    foreach ($policyReport in $policyReports) {
        foreach ($check in $policyReport.Checks) {
            $itemResult = if ($check.Pass) { '✅ Pass' } else { '❌ Fail' }
            $value = if ($null -eq $check.Value) { 'Not returned' } else { @($check.Value) -join ', ' }
            $resultMd += "| $($policyReport.Name) | $($check.CheckName) | $value | $itemResult |`n"
        }
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd
    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate:($investigatePolicies.Count -gt 0)
    return $testResult
}
