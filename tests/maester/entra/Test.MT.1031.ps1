function Test-MtCheckMT1031 {
    <#
    .SYNOPSIS
    Privileged role on Control Plane are managed by PIM only.

    .DESCRIPTION
    Runs the shared check Test-MtPimAlertsExists with -AlertId RolesAssignedOutsidePimAlert -FilteredAccessLevel ControlPlane.
    #>
    [MaesterTest(
        Id = 'MT.1031',
        Title = 'Privileged role on Control Plane are managed by PIM only.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Product = 'Entra ID',
        Tag = ('Maester', 'PIM', 'Privileged'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
        Author = 'Cloud-Architekt',
        Contributor = ('f-bader', 'merill', 'thomas-s-schmidt', 'nathanmcnulty')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $check = Test-MtPimAlertsExists -AlertId 'RolesAssignedOutsidePimAlert' -FilteredAccessLevel 'ControlPlane'
    if ($null -eq $check) { return $null }
    # Passed when the PIM alert is not active or has no affected items after filtering.
    return ($check.isActive -eq $false -or $check.numberOfAffectedItems -eq '0')
}
