function Test-MtCisMailForwardingBlocked {
    <#
    .SYNOPSIS
        Checks that mail flow rules and outbound spam policies do not forward mail to external recipients.

    .DESCRIPTION
        Checks that no enabled transport rule that is not in audit mode redirects mail outside the accepted domains, and that no outbound spam policy users receive allows automatic forwarding to external recipients.
        CIS Microsoft 365 Foundations Benchmark v7.0.0 (6.2.1, L1)

    .EXAMPLE
        Test-MtCisMailForwardingBlocked

        Returns true if no rule or policy forwards mail externally.

    .LINK
        https://maester.dev/docs/tests/CIS.M365.6.2.1
    #>
    [MaesterTest(
        Id = 'CIS.M365.6.2.1',
        Title = 'Ensure all forms of mail forwarding are blocked and/or disabled',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'mail-flow',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'T1114.003',
        Control = ('cis-m365:6.2.1', 'nist-800-53-r5:AC-4'),
        Service = 'ExchangeOnline',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose 'Getting mail flow rules and outbound spam policies...'
    $acceptedDomains = @(Get-MtExo -Request AcceptedDomain | ForEach-Object { "$($_.DomainName)".Trim().TrimEnd('.') } | Where-Object { $_ })
    $transportRules = @(Get-MtExo -Request TransportRule)
    $outboundPolicies = @(Get-MtExo -Request HostedOutboundSpamFilterPolicy)
    $enabledRules = @(Get-MtExo -Request HostedOutboundSpamFilterRule | Where-Object { $_.State -eq 'Enabled' })
    $rulePolicyNames = @($enabledRules | ForEach-Object { $_.HostedOutboundSpamFilterPolicy })
    $activeOutboundPolicies = @($outboundPolicies | Where-Object { $_.IsDefault -eq $true -or $rulePolicyNames -contains $_.Name })

    $findings = [System.Collections.Generic.List[object]]::new()
    $recipientCache = @{}
    foreach ($rule in $transportRules) {
        # Disabled and audit-mode rules do not perform the recipient actions.
        if ($rule.State -eq 'Disabled' -or $rule.Mode -in 'Audit', 'AuditAndNotify') { continue }
        foreach ($address in @($rule.RedirectMessageTo | Where-Object { $_ })) {
            $text = "$address".Trim()
            $recipientAddress = if ($address.ExternalEmailAddress) {
                "$($address.ExternalEmailAddress)"
            } elseif ($address.PrimarySmtpAddress) {
                "$($address.PrimarySmtpAddress)"
            } else {
                $text
            }
            $recipientAddress = $recipientAddress -replace '(?i)^smtp:', ''

            if ($recipientAddress -notmatch '@') {
                if ($recipientCache.ContainsKey($recipientAddress)) {
                    $recipient = $recipientCache[$recipientAddress]
                } else {
                    $recipient = Get-Recipient -Identity $recipientAddress -ErrorAction SilentlyContinue | Select-Object -First 1
                    $recipientCache[$recipientAddress] = $recipient
                }
                $recipientAddress = if ($recipient.ExternalEmailAddress) {
                    "$($recipient.ExternalEmailAddress)" -replace '(?i)^smtp:', ''
                } elseif ($recipient.PrimarySmtpAddress) {
                    "$($recipient.PrimarySmtpAddress)"
                } else {
                    $null
                }
            }

            if (-not $recipientAddress -or $recipientAddress -notmatch '@') {
                $findings.Add([pscustomobject]@{ Source = "Transport rule: $($rule.Name)"; Detail = "$text in RedirectMessageTo (target could not be resolved)" })
                continue
            }

            $at = $recipientAddress.LastIndexOf('@')
            $targetDomain = $recipientAddress.Substring($at + 1).Trim().TrimEnd('.')
            $isAcceptedDomain = $false
            foreach ($acceptedDomain in $acceptedDomains) {
                if ([string]::Equals($targetDomain, $acceptedDomain, [System.StringComparison]::OrdinalIgnoreCase)) {
                    $isAcceptedDomain = $true
                    break
                }
            }
            if (-not $isAcceptedDomain) {
                $findings.Add([pscustomobject]@{ Source = "Transport rule: $($rule.Name)"; Detail = "$text in RedirectMessageTo (external)" })
            }
        }
    }
    foreach ($policy in $activeOutboundPolicies) {
        if ($policy.AutoForwardingMode -ne 'Off') {
            $findings.Add([pscustomobject]@{ Source = "Outbound spam policy: $($policy.Name)"; Detail = "Automatic forwarding is $($policy.AutoForwardingMode)" })
        }
    }
    $testResult = $findings.Count -eq 0

    $passText = 'No mail flow rule or outbound spam policy forwards mail to external recipients.'
    $failText = "$($findings.Count) forwarding configuration(s) can send mail to external recipients."

    $resultMd = "| Source | Detail | Result |`n"
    $resultMd += "| --- | --- | --- |`n"
    foreach ($finding in $findings) {
        $resultMd += "| $($finding.Source) | $($finding.Detail) | ❌ Fail |`n"
    }
    if ($testResult) {
        $resultMd = "| Forwarding configurations to external recipients | Result |`n| --- | --- |`n| 0 | ✅ Pass |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. $passText`n`n%TestResult%"
    } else {
        $testResultMarkdown = "$failText`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultMd

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
