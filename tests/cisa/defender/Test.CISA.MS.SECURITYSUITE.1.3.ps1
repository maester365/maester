function Test-MtCisaSafeAttachment {
    <#
    .SYNOPSIS
    Checks the Safe Attachments policy that applies to all users

    .DESCRIPTION
    Emails identified as containing malware SHALL be quarantined or dropped. The highest-priority Safe Attachments policy that applies to all users must use Block or DynamicDelivery.

    .EXAMPLE
    Test-MtCisaSafeAttachment

    Returns true when the highest-priority Safe Attachments policy that applies to all users uses Block or DynamicDelivery.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeAttachment
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.1.3',
        Title = 'Emails identified as containing malware SHALL be quarantined or dropped.',
        Product = 'defender',
        Feature = 'safe-attachments',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1566.001',
        Control = 'cisa-scuba:MS.SECURITYSUITE.1.3',
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = ('JeanPhilippeGeorge', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtExo -Request SafeAttachmentPolicy)
    $presetRules = @(Get-MtExo -Request ATPProtectionPolicyRule)
    $attachmentRules = @(Get-MtExo -Request SafeAttachmentRule)
    $builtInRules = @(Get-MtExo -Request ATPBuiltInProtectionRule)
    $tenantDomains = @(Get-MtExo -Request AcceptedDomain | ForEach-Object { $_.Name } | Where-Object { $_ })

    $isEmpty = {
        param($value)
        $null -eq $value -or
        ($value -is [string] -and [string]::IsNullOrWhiteSpace($value)) -or
        @($value).Count -eq 0
    }

    $ruleCoversAllRecipients = {
        param($rule)
        foreach ($field in @('SentTo', 'SentToMemberOf', 'ExceptIfSentTo', 'ExceptIfSentToMemberOf', 'ExceptIfRecipientDomainIs')) {
            if (-not (& $isEmpty $rule.$field)) {
                return $false
            }
        }

        if (& $isEmpty $rule.RecipientDomainIs) {
            return $true
        }

        $recipientDomains = @($rule.RecipientDomainIs)
        $tenantDomains.Count -gt 0 -and @($tenantDomains | Where-Object { $_ -notin $recipientDomains }).Count -eq 0
    }

    $selectedPolicyName = $null
    $policyReference = $null
    $policy = $null

    foreach ($preset in @('Strict', 'Standard')) {
        $pattern = "(?i)$preset Preset Security Policy"
        $presetRule = $presetRules | Where-Object {
            $_.State -eq 'Enabled' -and
            $_.Identity -match $pattern -and
            (& $isEmpty $_.SentTo) -and
            (& $isEmpty $_.SentToMemberOf) -and
            (& $isEmpty $_.RecipientDomainIs)
        } | Select-Object -First 1

        if ($presetRule) {
            $policy = $policies | Where-Object { $_.Identity -match $pattern } | Select-Object -First 1
            if ($policy) {
                $selectedPolicyName = $policy.Identity
                $policyReference = $policy.Identity
                break
            }
        }
    }

    if (-not $policy) {
        $enabledRules = @($attachmentRules | Where-Object { $_.State -eq 'Enabled' })
        if ($enabledRules.Count -gt 0) {
            $highestPriority = ($enabledRules | Measure-Object -Property Priority -Minimum).Minimum
            $highestPriorityRules = @($enabledRules | Where-Object { $_.Priority -eq $highestPriority })
            $allRecipientRule = $highestPriorityRules | Where-Object { & $ruleCoversAllRecipients $_ } | Select-Object -First 1

            if ($allRecipientRule) {
                $selectedPolicyName = $allRecipientRule.SafeAttachmentPolicy
                $policyReference = $allRecipientRule.SafeAttachmentPolicy
            }
        }
    }

    if (-not $policy -and -not $policyReference) {
        $builtInRule = $builtInRules | Where-Object {
            (& $isEmpty $_.ExceptIfSentTo) -and
            (& $isEmpty $_.ExceptIfSentToMemberOf) -and
            (& $isEmpty $_.ExceptIfRecipientDomainIs)
        } | Select-Object -First 1

        if ($builtInRule) {
            $selectedPolicyName = 'Built-In Protection Policy'
            $policyReference = $builtInRule.SafeAttachmentPolicy
        }
    }

    if (-not $policy -and $policyReference) {
        $policy = $policies | Where-Object {
            $_.Identity -eq $policyReference -or $_.Name -eq $policyReference
        } | Select-Object -First 1
    }

    $action = if ($policy) { $policy.Action } else { 'Not found' }
    $testResult = $null -ne $policy -and $action -in @('Block', 'DynamicDelivery')
    $policyName = if ($policy) {
        if ($policy.Name) { $policy.Name } else { $policy.Identity }
    } elseif ($selectedPolicyName) {
        $selectedPolicyName
    } else {
        'None'
    }
    $result = "| Policy covering all users | Unknown malware action | Result |`n"
    $result += "| --- | --- | --- |`n"
    $result += "| $policyName | $action | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    if ($testResult) {
        $testResultMarkdown = "Well done. The highest-priority Safe Attachments policy covering all users uses **$action**.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "No Safe Attachments policy covering all users uses **Block** or **DynamicDelivery**. Configure the highest-priority policy to use one of these actions.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result
    Add-MtTestResultDetail -Result $testResultMarkdown

    return [bool]$testResult
}
