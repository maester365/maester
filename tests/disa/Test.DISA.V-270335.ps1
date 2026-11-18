function Test-MtDisaEntraNoPermanentPrivilegedAssignment {
    <#
    .SYNOPSIS
    Checks that no privileged role has a permanent active assignment.

    .DESCRIPTION
    DISA Microsoft Entra ID STIG (V-270335, CAT II): Microsoft Entra ID must use Privileged Identity Management (PIM).

    This test runs CISA.MS.AAD.7.4 (Test-MtCisaPermanentRoleAssignment). See the guide for what DISA asks and how the two compare.

    .EXAMPLE
    Test-MtDisaEntraNoPermanentPrivilegedAssignment

    Returns the result of CISA.MS.AAD.7.4 with DISA's values.

    .LINK
    https://maester.dev/docs/tests/DISA.V-270335
    #>
    [MaesterTest(
        Id = 'DISA.V-270335',
        Title = 'Microsoft Entra ID must use Privileged Identity Management (PIM).',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'T1098.003',
        Control = 'disa-stig-entra-id:V-270335',
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'merill'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisaPermanentRoleAssignment
}
