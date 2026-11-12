function Test-MtCisaSafeLinkDownloadScan {
    <#
    .SYNOPSIS
    Checks state of URL direct download scans

    .DESCRIPTION
    Direct download links SHOULD be scanned for malware.

    .EXAMPLE
    Test-MtCisaSafeLinkDownloadScan

    Returns true if URL direct download scan enabled

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeLinkDownloadScan
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.7.2',
        Title = 'Direct download links SHOULD be scanned for malware.',
        Product = 'exchange',
        RelatedProduct = 'defender',
        Feature = 'safe-links',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1204.001', 'T1566.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.7.2',
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
        $effectivePolicy.IsPreset -or
        ($policy.ScanUrls -eq $true -and $policy.DeliverMessageAfterScan -eq $true)
    )

    if ($testResult) {
        $message = "Well done. Direct download links are scanned for malware by the effective all-recipient Safe Links policy ($($effectivePolicy.PolicyName))."
    } else {
        $message = "Enable URL scanning and delivery after scanning on the effective all-recipient Safe Links policy. The benchmark requires both settings for a custom policy; an enabled all-recipient Standard or Strict preset policy also satisfies the requirement."
    }

    Add-MtTestResultDetail -Result $message
    return [bool]$testResult
}
