function Test-MtCheckMT1032 {
    <#
    .SYNOPSIS
    Limited number of Global Admins are assigned.

    .DESCRIPTION
    Runs the shared check Test-MtPimAlertsExists with -AlertId TooManyGlobalAdminsAssignedToTenantAlert.
    #>
    [MaesterTest(
        Id = 'MT.1032',
        Title = 'Limited number of Global Admins are assigned.',
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

    $check = Test-MtPimAlertsExists -AlertId 'TooManyGlobalAdminsAssignedToTenantAlert'
    if ($null -eq $check) { return $null }
    # Passed when the PIM alert is not active or has no affected items after filtering.
    return ($check.isActive -eq $false -or $check.numberOfAffectedItems -eq '0')
}
