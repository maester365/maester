function Test-MtCheckMT1026 {
    <#
    .SYNOPSIS
    No hybrid user with permanent role assignment on Control Plane.

    .DESCRIPTION
    Runs the shared check Test-MtPrivPermanentDirectoryRole with -FilteredAccessLevel "ControlPlane" -FilterPrincipal "HybridUser".
    #>
    [MaesterTest(
        Id = 'MT.1026',
        Title = 'No hybrid user with permanent role assignment on Control Plane.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('Maester', 'Privileged'),
        Service = 'Graph',
        Author = 'Cloud-Architekt',
        Contributor = ('f-bader', 'thomas-s-schmidt', 'nathanmcnulty')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel "ControlPlane" -FilterPrincipal "HybridUser"
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}
