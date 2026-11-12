function Test-MtCisaSafeAttachmentsForSharePoint {
    <#
    .SYNOPSIS
    Checks whether Safe Attachments scanning is enabled for SharePoint, OneDrive, and Teams.

    .DESCRIPTION
    SharePoint, OneDrive, and Teams message attachments SHOULD be scanned for malware. The global Safe Attachments setting is not covered by preset policies. This test delegates to ORCA.158, which checks the same setting.

    .EXAMPLE
    Test-MtCisaSafeAttachmentsForSharePoint

    Returns the result of ORCA.158.

    .LINK
    https://maester.dev/docs/commands/Test-MtCisaSafeAttachmentsForSharePoint
    #>
    [MaesterTest(
        Id = 'CISA.MS.SECURITYSUITE.1.4',
        Title = 'SharePoint, OneDrive, and Teams message attachments SHOULD be scanned for malware.',
        Product = 'defender',
        RelatedProduct = ('sharepoint', 'teams'),
        Feature = 'safe-attachments',
        Area = 'email-protection',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1080', 'T1204.002'),
        Control = 'cisa-scuba:MS.SECURITYSUITE.1.4',
        Service = 'ExchangeOnline',
        License = 'ATP_ENTERPRISE',
        Author = 'JeremyFinney-lgtm'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-ORCA158
}
