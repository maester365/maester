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
        Severity = 'High',
        Category = 'Maester/Entra',
        Tag = ('Maester', 'Privileged'),
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
