function Test-MtAsdOfficeExecutableContentBlocked {
    <#
    .SYNOPSIS
    Checks that assigned Intune policies set the attack surface reduction rules "Block Office applications from creating executable content" and "Block executable content from email client and webmail" to Block.

    .DESCRIPTION
    ISM-1668 (Essential Eight, User application hardening, Maturity Level Two) asks that Microsoft Office is blocked from creating executable content.

    Attack surface reduction rules are read from every Intune Windows configuration policy (Endpoint security
    and settings catalog share the setting definition IDs). The check passes when assigned policies set both
    rules to Block; Audit and Warn only report the behaviour and do not satisfy the control.
    Attachments opened from Outlook and webmail are covered by their own rule, so ASD's assessment process guide asks for both.

    .EXAMPLE
    Test-MtAsdOfficeExecutableContentBlocked

    Returns true when assigned policies set both rules to Block.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1668
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1668',
        Title = 'Microsoft Office is blocked from creating executable content.',
        Product = 'intune',
        RelatedProduct = 'defender',
        Feature = 'endpoint-security',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1204.002', 'T1566.001'),
        Control = ('essential-eight:ISM-1668', 'nist-800-53-r5:CM-7'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtAsdAsrRule -Rule ([ordered]@{
            blockofficeapplicationsfromcreatingexecutablecontent = 'Block Office applications from creating executable content'
            blockexecutablecontentfromemailclientandwebmail = 'Block executable content from email client and webmail'
        })
}
