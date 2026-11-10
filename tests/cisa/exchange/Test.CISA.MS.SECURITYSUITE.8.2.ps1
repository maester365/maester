function Test-MtCisaAntiSpamSafeList {
    <#
    .SYNOPSIS
    Checks state of anti-spam policies

    .DESCRIPTION
    Safe lists SHOULD NOT be enabled.

    .EXAMPLE
    Test-MtCisaAntiSpamSafeList

    Returns true if Safe List is disabled in anti-spam policy

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaAntiSpamSafeList
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.8.2',
        Title = 'Safe lists SHOULD NOT be enabled.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'anti-spam',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566', 'T1684.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.8.2',
        Service = 'ExchangeOnline',
        Author = 'soulemike',
        Contributor = ('merill', 'JeremyFinney-lgtm')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $policies = @(Get-MtExo -Request HostedConnectionFilterPolicy)
    $policiesWithSafeList = @($policies | Where-Object { $_.EnableSafeList -eq $true })
    $testResult = $policies.Count -gt 0 -and $policiesWithSafeList.Count -eq 0

    $portalLink = "https://security.microsoft.com/antispam"

    if ($testResult) {
        $testResultMarkdown = "Well done. [Safe List]($portalLink) is disabled in your tenant."
    } else {
        $testResultMarkdown = "Disable Safe List on every connection filter policy returned by [the anti-spam policies page]($portalLink)."
        if ($policies.Count -eq 0) {
            $testResultMarkdown = "No connection filter policy was returned. Verify the connection to Exchange Online and confirm that the policy data is available."
        } elseif ($policiesWithSafeList.Count -gt 0) {
            $policyNames = @($policiesWithSafeList | ForEach-Object { $_.Name })
            $testResultMarkdown += "`n`nSafe List is enabled on: $($policyNames -join ', ')."
        }
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return [bool]$testResult
}
