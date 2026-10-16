function Test-MtCheckCISAMSAAD79 {
    <#
    .SYNOPSIS
    User activation of other highly privileged roles SHOULD trigger an alert.

    .DESCRIPTION
    Runs the shared check Test-MtCisaActivationNotification.
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.7.9',
        Title = 'User activation of other highly privileged roles SHOULD trigger an alert.',
        Product = 'entra',
        Feature = 'privileged-identity-management',
        Area = 'privileged-access',
        ResourceType = 'DirectoryRole',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = ('T1098.003', 'T1136.003', 'T1548.005'),
        Control = 'cisa-scuba:MS.AAD.7.9',
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = ('michaelmsonne', 'JeanPhilippeGeorge')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCisaActivationNotification
    if ($null -eq $result) { return $null }
    return $result
}
