function Test-MtCisaPartnerDomainImpersonationProtection {
    <#
    .SYNOPSIS
    Checks domain impersonation protection for configured partner domains.

    .DESCRIPTION
    Domain impersonation protection SHOULD be enabled for key suppliers and partners and apply to all recipients.

    .PARAMETER PartnerDomains
    Partner email domains that must be included in impersonation protection.

    .EXAMPLE
    Test-MtCisaPartnerDomainImpersonationProtection -PartnerDomains 'partner.example'

    Returns true when an enabled policy applying to all recipients protects every configured partner domain.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaPartnerDomainImpersonationProtection
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.2.3',
        Title = 'Domain impersonation protection SHOULD be added for key suppliers and partners.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-phishing',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.2.3',
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        [string[]] $PartnerDomains = @()
    )

    $configuredDomains = @(
        $PartnerDomains |
            ForEach-Object { ([string]$_).Trim().ToLowerInvariant() } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
    $policies = @(Get-MtCisaEffectiveAntiPhishPolicy -RequireDefenderProtection)
    $compliantPolicies = @(
        $policies | Where-Object {
            $policy = $_
            $targetDomains = @($policy.TargetedDomainsToProtect | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
            $missingDomains = @($configuredDomains | Where-Object { $_ -notin $targetDomains })
            $action = ([string]$policy.TargetedDomainProtectionAction).Trim().ToLowerInvariant()
            $_.EnableTargetedDomainsProtection -eq $true -and
            -not [string]::IsNullOrWhiteSpace($action) -and
            $action -notin @('noaction', 'bccmessage') -and
            $missingDomains.Count -eq 0
        }
    )
    $testResult = $configuredDomains.Count -gt 0 -and $compliantPolicies.Count -gt 0

    $result = "| Effective policy | Partner-domain protection | Configured partners protected | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    foreach ($policy in $policies | Sort-Object -Property Identity) {
        $targetDomains = @($policy.TargetedDomainsToProtect | ForEach-Object { ([string]$_).Trim().ToLowerInvariant() })
        $action = ([string]$policy.TargetedDomainProtectionAction).Trim().ToLowerInvariant()
        $protected = $policy.EnableTargetedDomainsProtection -eq $true -and
            -not [string]::IsNullOrWhiteSpace($action) -and
            $action -notin @('noaction', 'bccmessage') -and
            $configuredDomains.Count -gt 0 -and
            @($configuredDomains | Where-Object { $_ -notin $targetDomains }).Count -eq 0
        $status = if ($protected) { '✅ Pass' } else { '❌ Fail' }
        $result += "| $($policy.Identity) | $(if ($policy.EnableTargetedDomainsProtection) { 'Enabled' } else { 'Disabled' }) | $(@($configuredDomains | Where-Object { $_ -in $targetDomains }) -join ', ') | $status |`n"
    }

    if ($testResult) {
        $message = "Well done. An enabled anti-phishing policy applying to all recipients protects every configured partner domain.`n`n%TestResult%"
    } elseif ($configuredDomains.Count -eq 0) {
        $message = "Configure PartnerDomains for this test and add those domains to an all-recipient anti-phishing policy.`n`n%TestResult%"
    } else {
        $message = "Enable targeted-domain impersonation protection for every configured partner domain, using an action that redirects, moves to Junk Email, quarantines, or deletes the message, in an anti-phishing policy that applies to all recipients.`n`n%TestResult%"
    }

    Add-MtTestResultDetail -Result ($message -replace '%TestResult%', $result)
    return [bool]$testResult
}
