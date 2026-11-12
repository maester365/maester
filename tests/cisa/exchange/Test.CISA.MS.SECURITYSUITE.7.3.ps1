function Test-MtCisaSafeLinkClickTracking {
    <#
    .SYNOPSIS
    Checks whether user click tracking is enabled on the effective all-recipient Safe Links policy.

    .DESCRIPTION
    User click tracking SHOULD be enabled.

    .EXAMPLE
    Test-MtCisaSafeLinkClickTracking

    Returns true if user click tracking is enabled on the effective all-recipient Safe Links policy.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeLinkClickTracking
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.7.3',
        Title = 'User click tracking SHOULD be enabled.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'safe-links',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1566.002', 'T1204.001'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.7.3',
        Service = ('ExchangeOnline', 'Graph'),
        License = 'ATP_ENTERPRISE',
        Author = 'soulemike',
        Contributor = ('thomas-s-schmidt', 'JeremyFinney-lgtm', 'earbona23')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $effectivePolicy = Get-MtCisaEffectiveSafeLinksPolicy
    $policy = $effectivePolicy.Policy
    $testResult = $null -ne $policy -and (
        $effectivePolicy.IsPreset -or $policy.TrackClicks -eq $true
    )

    if ($testResult) {
        $message = "Well done. User click tracking is enabled by the effective all-recipient Safe Links policy ($($effectivePolicy.PolicyName))."
    } else {
        $message = "Enable user click tracking on the effective all-recipient Safe Links policy. An enabled all-recipient Standard or Strict preset policy also satisfies the requirement."
    }

    Add-MtTestResultDetail -Result $message
    return [bool]$testResult
}
