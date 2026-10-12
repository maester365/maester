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
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1078.004',
        Control = ('nist-800-53-r5:AC-6', 'nist-800-53-r5:AC-2(3)'),
        Service = 'Graph',
        License = 'AAD_PREMIUM_P2',
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
