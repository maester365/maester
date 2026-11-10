function Test-MtCisaDlpEndpointRestriction {
    <#
    .SYNOPSIS
    Prompts review of manual endpoint DLP restrictions.

    .DESCRIPTION
    The baseline's endpoint DLP requirement is manual and applies only when at least one device is onboarded to Defender for Endpoint. ScubaGear does not automate this assessment.

    .EXAMPLE
    Test-MtCisaDlpEndpointRestriction

    Returns an Investigate result with the manual verification steps.

    .LINK
    https://maester.dev/docs/tests/CISA.MS.SECURITYSUITE.3.5
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.3.5',
        Title = 'The DLP policy SHOULD block access to sensitive information by restricted applications and unwanted Bluetooth applications.',
        Product = 'purview',
        RelatedProduct = 'defender',
        Feature = 'data-loss-prevention',
        Area = 'data-protection',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'T1011.001',
        Control = 'cisa-scuba:MS.SECURITYSUITE.3.5',
        Service = 'None',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = @'
ScubaGear marks this requirement as manual and not implemented. First confirm whether at least one device is onboarded to Defender for Endpoint; the baseline applies only when one is onboarded.

If applicable, in Microsoft Purview verify that the endpoint DLP policy blocks access to sensitive information by restricted applications and blocks "Copy or move using unallowed Bluetooth app." Use an approved third-party solution if it provides the required protection instead.
'@

    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
