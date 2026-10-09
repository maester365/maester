function Test-MtCheckMT1029 {
    <#
    .SYNOPSIS
    Stale accounts are not assigned to privileged roles.

    .DESCRIPTION
    Runs the shared check Test-MtPimAlertsExists with -AlertId StaleSignInAlert.
    #>
    [MaesterTest(
        Id = 'MT.1029',
        Title = 'Stale accounts are not assigned to privileged roles.',
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

    $check = Test-MtPimAlertsExists -AlertId 'StaleSignInAlert'
    if ($null -eq $check) { return $null }
    # Passed when the PIM alert is not active or has no affected items after filtering.
    return ($check.isActive -eq $false -or $check.numberOfAffectedItems -eq '0')
}
