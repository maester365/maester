function Test-MtCisaMalwareZap {
    <#
    .SYNOPSIS
    Checks the highest-priority anti-malware policy that applies to all users.

    .DESCRIPTION
    Email scanning SHALL be capable of reviewing emails after delivery.

    .EXAMPLE
    Test-MtCisaMalwareZap

    Returns true when the effective all-recipient anti-malware policy has zero-hour auto purge enabled.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaMalwareZap
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.1.2',
        Title = 'Email scanning SHALL be capable of reviewing emails after delivery.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Policy',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1204.002', 'T1566.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.1.2',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = 'JeanPhilippeGeorge'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policy = Get-MtCisaEffectiveAntiMalwarePolicy
    $testResult = $null -ne $policy -and $policy.ZapEnabled -eq $true

    $portalLink = "https://security.microsoft.com/antimalwarev2"
    $policyName = if ($policy) { $policy.Identity } else { 'Not found' }
    $result = "| Effective policy | Zero-hour auto purge | Result |`n"
    $result += "| --- | --- | --- |`n"
    $result += "| $policyName | $($policy.ZapEnabled) | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"
    $testResultMarkdown = if ($testResult) {
        "Well done. Zero-hour auto purge is enabled on the effective anti-malware policy. See [anti-malware policies]($portalLink).`n`n$result"
    } else {
        "Zero-hour auto purge is not enabled on the effective anti-malware policy that applies to all users. Configure it in [anti-malware policies]($portalLink).`n`n$result"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
