function Get-MtCisaEffectiveSafeLinksPolicy {
    [CmdletBinding()]
    [OutputType([object])]
    param()

    $policies = @(Get-MtExo -Request SafeLinksPolicy)
    $presetRules = @(Get-MtExo -Request EOPProtectionPolicyRule)
    $safeLinksRules = @(Get-MtExo -Request SafeLinksRule)

    $isEmpty = {
        param($Value)
        $null -eq $Value -or
        ($Value -is [string] -and [string]::IsNullOrWhiteSpace($Value)) -or
        @($Value).Count -eq 0
    }

    $activePresetRules = @(
        $presetRules | Where-Object {
            $_.State -eq 'Enabled' -and
            $_.Identity -match '(?i)(Standard|Strict) Preset Security Policy' -and
            (& $isEmpty $_.SentTo) -and
            (& $isEmpty $_.SentToMemberOf) -and
            (& $isEmpty $_.RecipientDomainIs)
        }
    )

    $selectedPolicy = $null
    $selectedPolicyName = 'Built-In Protection Policy'
    $selectionReason = 'Built-in protection'

    if ($activePresetRules.Count -gt 0) {
        $presetType = if (@($activePresetRules | Where-Object { $_.Identity -match '(?i)Strict Preset Security Policy' }).Count -gt 0) {
            'Strict'
        } else {
            'Standard'
        }
        $selectedPolicy = $policies |
            Where-Object { $_.RecommendedPolicyType -eq $presetType } |
            Select-Object -First 1
        if ($selectedPolicy) {
            $selectedPolicyName = $selectedPolicy.Identity
            $selectionReason = "$presetType preset policy covers all recipients"
        } else {
            $selectedPolicyName = "$presetType preset policy data not returned"
            $selectionReason = 'Enabled all-recipient preset rule'
        }
    } else {
        $allRecipientRules = @(
            $safeLinksRules | Where-Object {
                $_.State -eq 'Enabled' -and
                (& $isEmpty $_.SentTo) -and
                (& $isEmpty $_.SentToMemberOf) -and
                (& $isEmpty $_.RecipientDomainIs)
            }
        )
        if ($allRecipientRules.Count -gt 0) {
            $highestPriority = ($allRecipientRules | Measure-Object -Property Priority -Minimum).Minimum
            $selectedRule = $allRecipientRules |
                Where-Object { $_.Priority -eq $highestPriority } |
                Select-Object -First 1
            $policyReference = $selectedRule.SafeLinksPolicy
            $selectedPolicy = $policies |
                Where-Object { $_.Identity -eq $policyReference -or $_.Name -eq $policyReference } |
                Select-Object -First 1
            $selectedPolicyName = if ($selectedPolicy) { $selectedPolicy.Identity } else { [string]$policyReference }
            $selectionReason = "Highest-priority all-recipient rule (priority $highestPriority)"
        } else {
            $selectedPolicy = $policies |
                Where-Object { $_.Identity -eq 'Built-In Protection Policy' -or $_.Name -eq 'Built-In Protection Policy' } |
                Select-Object -First 1
        }
    }

    [pscustomobject]@{
        Policy          = $selectedPolicy
        PolicyName      = $selectedPolicyName
        SelectionReason = $selectionReason
        IsPreset        = $activePresetRules.Count -gt 0
    }
}
