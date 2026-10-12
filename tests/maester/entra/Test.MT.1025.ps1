function Test-MtCheckMT1025 {
    <#
    .SYNOPSIS
    No external user with permanent role assignment on Control Plane.

    .DESCRIPTION
    Runs the shared check Test-MtPrivPermanentDirectoryRole with -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ExternalUser".
    #>
    [MaesterTest(
        Id = 'MT.1025',
        Title = 'No external user with permanent role assignment on Control Plane.',
        Product = 'entra',
        Feature = 'roles',
        Area = 'privileged-access',
        ResourceType = 'User',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = ('T1078.004', 'T1199'),
        Control = ('nist-800-53-r5:AC-6(5)', 'nist-800-53-r5:AC-2(7)'),
        Service = 'Graph',
        Author = 'Cloud-Architekt',
        Contributor = ('f-bader', 'thomas-s-schmidt', 'nathanmcnulty')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ExternalUser"
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
