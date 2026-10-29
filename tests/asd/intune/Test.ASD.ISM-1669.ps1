function Test-MtAsdOfficeCodeInjectionBlocked {
    <#
    .SYNOPSIS
    Checks that an assigned Intune policy sets the attack surface reduction rule "Block Office applications from injecting code into other processes" to Block.

    .DESCRIPTION
    ISM-1669 (Essential Eight, User application hardening, Maturity Level Two) asks that Microsoft Office is blocked from injecting code into other processes.

    Attack surface reduction rules are read from every Intune Windows configuration policy (Endpoint security
    and settings catalog share the setting definition IDs). The check passes when an assigned policy sets the
    rule to Block; Audit and Warn only report the behaviour and do not satisfy the control.

    .EXAMPLE
    Test-MtAsdOfficeCodeInjectionBlocked

    Returns true when an assigned policy sets the rule to Block.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1669
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1669',
        Title = 'Microsoft Office is blocked from injecting code into other processes.',
        Product = 'intune',
        RelatedProduct = 'defender',
        Feature = 'endpoint-security',
        Area = 'devices',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1055', 'T1204.002'),
        Control = ('essential-eight:ISM-1669', 'nist-800-53-r5:CM-7'),
        Service = 'Graph',
        License = 'INTUNE_A',
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtAsdAsrRule -Rule ([ordered]@{
            blockofficeapplicationsfrominjectingcodeintootherprocesses = 'Block Office applications from injecting code into other processes'
        })
}
