function Get-MtExoActiveSpamPolicyEvaluation {
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [scriptblock] $HasViolation
    )

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
    $policyEvaluations = @(
        foreach ($policy in $activePolicies) {
            [pscustomobject]@{
                Policy       = $policy
                HasViolation = [bool](& $HasViolation $policy)
            }
        }
    )

    $strictCompliant = @(
        $policyEvaluations | Where-Object {
            $_.Policy.RecommendedPolicyType -eq 'Strict' -and -not $_.HasViolation
        }
    ).Count -gt 0
    $standardCompliant = @(
        $policyEvaluations | Where-Object {
            $_.Policy.RecommendedPolicyType -eq 'Standard' -and -not $_.HasViolation
        }
    ).Count -gt 0
    $anyPresetCompliant = $strictCompliant -or $standardCompliant
    $anyCustomCompliant = @(
        $policyEvaluations | Where-Object {
            $_.Policy.RecommendedPolicyType -eq 'Custom' -and
            $_.Policy.IsDefault -eq $false -and
            -not $_.HasViolation
        }
    ).Count -gt 0

    $failingPolicies = @(
        $policyEvaluations | Where-Object {
            $policy = $_.Policy
            if ($_.HasViolation) {
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
        } | ForEach-Object { $_.Policy }
    )

    $cascadeStatus = if ($strictCompliant) {
        'Strict preset is active and compliant; lower-priority policies are shielded.'
    } elseif ($standardCompliant) {
        'Standard preset is active and compliant; custom and default policies are shielded.'
    } elseif ($anyCustomCompliant) {
        'No active preset is compliant; a compliant all-recipient custom policy shields the default policy.'
    } else {
        'All active policies were evaluated; no policy was shielded by a compliant higher-priority preset or custom policy.'
    }

    [pscustomobject]@{
        ActivePolicies      = $activePolicies
        FailingPolicies     = $failingPolicies
        StrictCompliant     = $strictCompliant
        AnyPresetCompliant  = $anyPresetCompliant
        AnyCustomCompliant  = $anyCustomCompliant
        CascadeStatus       = $cascadeStatus
        TestResult          = ($activePolicies.Count -gt 0 -and $failingPolicies.Count -eq 0)
    }
}
