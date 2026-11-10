function Test-MtCisaSpamBypass {
    <#
    .SYNOPSIS
    Checks state of spam filter

    .DESCRIPTION
    Allowed domains SHALL NOT be added to inbound anti-spam protection policies.

    .EXAMPLE
    Test-MtCisaSpamBypass

    Returns true if spam filter enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSpamBypass
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.6.2',
        Title = 'Allowed domains SHALL NOT be added to inbound anti-spam protection policies.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Policy',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1566', 'T1684.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.6.2',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtExo -Request HostedContentFilterPolicy)
    $presetRules = @(Get-MtExo -Request EOPProtectionPolicyRule)
    $customRules = @(Get-MtExo -Request HostedContentFilterRule)
    $tenantDomains = @(
        Get-MtExo -Request AcceptedDomain |
            ForEach-Object {
                $domain = if ($_.DomainName) { $_.DomainName } else { $_.Name }
                ([string]$domain).Trim().ToLowerInvariant()
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    $isEmpty = {
        param($Value)
        $null -eq $Value -or
        ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) -or
        @($Value).Count -eq 0
    }

    $activePresetPolicies = @(
        foreach ($rule in $presetRules) {
            if (
                $rule.State -eq 'Enabled' -and
                $rule.Identity -match '(?i)(Standard|Strict) Preset Security Policy' -and
                (& $isEmpty $rule.SentTo) -and
                (& $isEmpty $rule.SentToMemberOf) -and
                (& $isEmpty $rule.RecipientDomainIs)
            ) {
                $rule.HostedContentFilterPolicy
            }
        }
    )

    $activeCustomPolicies = @(
        foreach ($rule in $customRules) {
            if ($rule.State -ne 'Enabled') {
                continue
            }

            $hasNoRecipientScope = $true
            foreach ($field in @('SentTo', 'SentToMemberOf', 'ExceptIfSentTo', 'ExceptIfSentToMemberOf', 'ExceptIfRecipientDomainIs')) {
                if (-not (& $isEmpty $rule.$field)) {
                    $hasNoRecipientScope = $false
                    break
                }
            }

            if (-not $hasNoRecipientScope) {
                continue
            }

            if (-not (& $isEmpty $rule.RecipientDomainIs)) {
                if ($tenantDomains.Count -eq 0) {
                    throw 'Cannot determine whether the enabled all-recipient anti-spam rule covers the tenant because no accepted domains were returned.'
                }

                $recipientDomains = @($rule.RecipientDomainIs | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
                if (@($tenantDomains | Where-Object { $_ -notin $recipientDomains }).Count -gt 0) {
                    continue
                }
            }

            $rule.HostedContentFilterPolicy
        }
    )

    $activePolicies = @(
        $policies | Where-Object {
            $_.IsDefault -eq $true -or
            ($_.RecommendedPolicyType -in @('Standard', 'Strict') -and $_.Identity -in $activePresetPolicies) -or
            ($_.RecommendedPolicyType -eq 'Custom' -and $_.IsDefault -eq $false -and $_.Identity -in $activeCustomPolicies)
        }
    )

    $strictCompliant = @(
        $activePolicies | Where-Object {
            $_.RecommendedPolicyType -eq 'Strict' -and @($_.AllowedSenderDomains).Count -eq 0
        }
    ).Count -gt 0
    $standardCompliant = @(
        $activePolicies | Where-Object {
            $_.RecommendedPolicyType -eq 'Standard' -and @($_.AllowedSenderDomains).Count -eq 0
        }
    ).Count -gt 0
    $anyPresetCompliant = $strictCompliant -or $standardCompliant
    $anyCustomCompliant = @(
        $activePolicies | Where-Object {
            $_.RecommendedPolicyType -eq 'Custom' -and
            $_.IsDefault -eq $false -and
            @($_.AllowedSenderDomains).Count -eq 0
        }
    ).Count -gt 0

    $failingPolicies = @(
        $activePolicies | Where-Object {
            $policy = $_
            if (@($policy.AllowedSenderDomains).Count -gt 0) {
                if ($policy.IsDefault -eq $true) {
                    -not $anyPresetCompliant -and -not $anyCustomCompliant
                } elseif ($policy.RecommendedPolicyType -eq 'Strict') {
                    $true
                } elseif ($policy.RecommendedPolicyType -eq 'Standard') {
                    -not $strictCompliant
                } elseif ($policy.RecommendedPolicyType -eq 'Custom') {
                    -not $anyPresetCompliant
                }
            }
        }
    )

    $cascadeStatus = if ($strictCompliant) {
        'Strict preset is active and compliant; lower-priority policies are shielded.'
    } elseif ($standardCompliant) {
        'Standard preset is active and compliant; custom and default policies are shielded.'
    } elseif ($anyCustomCompliant) {
        'No active preset is compliant; a compliant all-recipient custom policy shields the default policy.'
    } else {
        'No active compliant preset or custom policy; all active policies were evaluated.'
    }
    $testResult = $activePolicies.Count -gt 0 -and $failingPolicies.Count -eq 0

    $result = "| Active policy | Type | Allowed domains | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($policy in $activePolicies | Sort-Object -Property Identity) {
        $isFailing = $policy.Identity -in @($failingPolicies | ForEach-Object { $_.Identity })
        $isShielded = if ($policy.IsDefault -eq $true) {
            $anyPresetCompliant -or $anyCustomCompliant
        } elseif ($policy.RecommendedPolicyType -eq 'Standard') {
            $strictCompliant
        } elseif ($policy.RecommendedPolicyType -eq 'Custom') {
            $anyPresetCompliant
        } else {
            $false
        }
        $status = if ($isFailing) { '❌ Fail' } elseif ($isShielded) { 'Not evaluated (shielded)' } else { '✅ Pass' }
        $result += "| $($policy.Identity) | $($policy.RecommendedPolicyType) | $($policy.AllowedSenderDomains -join ', ') | $status |`n"
    }
    if ($activePolicies.Count -eq 0) {
        $result += "| None | — | — | ❌ Fail |`n"
    }

    if ($testResult) {
        $message = "Well done. $cascadeStatus`n`n%TestResult%"
    } else {
        $message = "One or more effective inbound anti-spam policies have allowed sender domains. $cascadeStatus`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
