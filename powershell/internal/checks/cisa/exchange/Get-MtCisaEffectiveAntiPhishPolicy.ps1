function Get-MtCisaEffectiveAntiPhishPolicy {
    <#
    .SYNOPSIS
    Gets enabled anti-phishing policies that effectively cover all tenant recipients.

    .DESCRIPTION
    Returns policies whose recipient rules cover every accepted domain without recipient exclusions.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    $policies = @(Get-MtExo -Request AntiPhishPolicy)
    $antiPhishRules = @(Get-MtExo -Request AntiPhishRule)
    $presetRules = @(Get-MtExo -Request EOPProtectionPolicyRule)
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

    $coversAllTenantDomains = {
        param($Rule)
        foreach ($field in @('SentTo', 'SentToMemberOf', 'ExceptIfSentTo', 'ExceptIfSentToMemberOf', 'ExceptIfRecipientDomainIs')) {
            if (-not (& $isEmpty $Rule.$field)) {
                return $false
            }
        }

        if (& $isEmpty $Rule.RecipientDomainIs) {
            return $tenantDomains.Count -gt 0
        }

        $recipientDomains = @($Rule.RecipientDomainIs | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        $tenantDomains.Count -gt 0 -and @($tenantDomains | Where-Object { $_ -notin $recipientDomains }).Count -eq 0
    }

    $effectivePolicies = foreach ($policy in $policies | Where-Object { $_.Enabled -eq $true }) {
        $coversAllRecipients = $policy.IsDefault -eq $true

        if (-not $coversAllRecipients -and $policy.Identity -match '(?i)(Standard|Strict) Preset Security Policy') {
            $coversAllRecipients = @(
                $presetRules | Where-Object {
                    $_.State -eq 'Enabled' -and
                    $_.Identity -match [regex]::Escape($policy.RecommendedPolicyType) -and
                    (& $coversAllTenantDomains $_)
                }
            ).Count -gt 0
        } elseif (-not $coversAllRecipients) {
            $policyRules = @(
                $antiPhishRules | Where-Object {
                    $_.State -eq 'Enabled' -and
                    ($_.AntiPhishPolicy -eq $policy.Name -or $_.AntiPhishPolicy -eq $policy.Identity) -and
                    (& $coversAllTenantDomains $_)
                }
            )
            $coversAllRecipients = $tenantDomains.Count -gt 0 -and $policyRules.Count -gt 0
        }

        if ($coversAllRecipients) {
            $policy
        }
    }

    return @($effectivePolicies)
}
