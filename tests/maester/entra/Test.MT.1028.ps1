function Test-MtCheckMT1028 {
    <#
    .SYNOPSIS
    No user with mailbox and permanent role assignment on Control Plane.

    .DESCRIPTION
    Runs the shared check Test-MtPrivPermanentDirectoryRole with -FilteredAccessLevel "ControlPlane" -FilterPrincipal "UserMailbox".
    #>
    [MaesterTest(
        Id = 'MT.1028',
        Title = 'No user with mailbox and permanent role assignment on Control Plane.',
        Product = 'entra',
        Feature = 'roles',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1566'),
        Control = ('nist-800-53-r5:AC-6(5)', 'nist-800-53-r5:AC-6(2)'),
        Service = 'Graph',
        Author = 'Cloud-Architekt',
        Contributor = ('f-bader', 'thomas-s-schmidt', 'nathanmcnulty')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel "ControlPlane" -FilterPrincipal "UserMailbox"
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
