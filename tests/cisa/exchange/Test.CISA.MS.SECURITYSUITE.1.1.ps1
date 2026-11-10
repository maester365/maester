function Test-MtCisaBlockExecutable {
    <#
    .SYNOPSIS
    Checks the highest-priority anti-malware policy that applies to all users.

    .DESCRIPTION
    Emails with click-to-run file attachments SHALL be blocked including, at a minimum, .exe, .cmd, and .vbe files.

    .EXAMPLE
    Test-MtCisaBlockExecutable

    Returns true when the effective all-recipient anti-malware policy blocks the required file types.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaBlockExecutable
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.1.1',
        Title = 'Emails with click-to-run file attachments SHALL be blocked including, at a minimum, .exe, .cmd, and .vbe files.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-malware',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1204.002', 'T1566.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.1.1',
        Service = 'ExchangeOnline',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $clickToRunExtensions = @(
        "cmd",
        "exe",
        "vbe"
    )
    $policy = Get-MtCisaEffectiveAntiMalwarePolicy
    $blockedExtensions = @($clickToRunExtensions | Where-Object { $_ -in $policy.FileTypes })
    $testResult = $null -ne $policy -and
        $policy.EnableFileFilter -eq $true -and
        $blockedExtensions.Count -eq $clickToRunExtensions.Count

    $portalLink = "https://security.microsoft.com/presetSecurityPolicies"
    $policyName = if ($policy) { $policy.Identity } else { 'Not found' }
    $result = "| Effective policy | File filter enabled | Required extensions | Result |`n"
    $result += "| --- | --- | --- | --- |`n"
    $result += "| $policyName | $($policy.EnableFileFilter) | $($blockedExtensions -join ', ') | $(if ($testResult) { '✅ Pass' } else { '❌ Fail' }) |`n"

    $testResultMarkdown = if ($testResult) {
        "Well done. The effective anti-malware policy blocks the required click-to-run file types. See [anti-malware policies]($portalLink).`n`n$result"
    } else {
        "The effective anti-malware policy that applies to all users does not block all required click-to-run file types. Update it in [anti-malware policies]($portalLink).`n`n$result"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
