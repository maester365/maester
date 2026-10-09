function Test-MtCheckMT1030 {
    <#
    .SYNOPSIS
    Eligible role assignments on Control Plane are in use by administrators.

    .DESCRIPTION
    Runs the shared check Test-MtPimAlertsExists with -AlertId RedundantAssignmentAlert -FilteredAccessLevel ControlPlane.
    #>
    [MaesterTest(
        Id = 'MT.1030',
        Title = 'Eligible role assignments on Control Plane are in use by administrators.',
        Severity = 'High',
        Category = 'Maester/Entra',
        Tag = ('Maester', 'PIM', 'Privileged'),
        Service = 'Graph',
        CompatibleLicense = 'AAD_PREMIUM_P2',
        Author = 'Cloud-Architekt',
        Contributor = ('f-bader', 'merill', 'thomas-s-schmidt', 'nathanmcnulty')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $check = Test-MtPimAlertsExists -AlertId 'RedundantAssignmentAlert' -FilteredAccessLevel 'ControlPlane'
    if ($null -eq $check) { return $null }
    # Passed when the PIM alert is not active or has no affected items after filtering.
    return ($check.isActive -eq $false -or $check.numberOfAffectedItems -eq '0')
}
