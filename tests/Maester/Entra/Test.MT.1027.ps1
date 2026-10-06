function Test-MtCheckMT1027 {
    <#
    .SYNOPSIS
    No Service Principal with Client Secret and permanent role assignment on Control Plane.

    .DESCRIPTION
    Runs the shared check Test-MtPrivPermanentDirectoryRole with -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ServicePrincipalClientSecret".
    #>
    [MaesterTest(
        Id = 'MT.1027',
        Title = 'No Service Principal with Client Secret and permanent role assignment on Control Plane.',
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

    $result = Test-MtPrivPermanentDirectoryRole -FilteredAccessLevel "ControlPlane" -FilterPrincipal "ServicePrincipalClientSecret"
    if ($null -eq $result) { return $null }
    # The shared check returns $true when the tenant is not compliant.
    return (-not $result)
}