function Test-MtAsdJustInTimeAdministration {
    <#
    .SYNOPSIS
    Checks that privileged directory roles are activated when needed and not assigned, so that administration is just-in-time.

    .DESCRIPTION
    ISM-1649 (Essential Eight, Restrict administrative privileges, Maturity Level Three) asks that just-in-time
    administration is used for the administration of systems and their resources. ASD's assessment guide says
    privileged users are granted access "immediately before that access is required and for only as long as it
    is required", and the ASD Blueprint for Secure Cloud makes every Microsoft Entra role an eligible assignment,
    with permanent active assignments only for break glass accounts. That is what CIS.M365.5.3.1 checks: an
    active assignment that was not made by an activation fails, whether or not it has an end date. This test
    runs that check (Test-MtCisPrivilegedRolesActivatedNotAssigned).

    .EXAMPLE
    Test-MtAsdJustInTimeAdministration

    Returns true when every active assignment to a privileged role was made by an activation, apart from the emergency access accounts.

    .LINK
    https://maester.dev/docs/tests/ASD.ISM-1649
    #>
    [MaesterTest(
        Id = 'ASD.ISM-1649',
        Title = 'Just-in-time administration is used for the administration of systems and their resources.',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1098.003'),
        Control = ('essential-eight:ISM-1649', 'nist-800-53-r5:AC-2(7)', 'nist-800-53-r5:AC-6(5)'),
        Service = 'Graph',
        License = ('AAD_PREMIUM_P2', 'Entra_Identity_Governance'),
        Author = 'jusso-dev'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtCisPrivilegedRolesActivatedNotAssigned
}
