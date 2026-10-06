function Test-MtCheckCISAMSAAD78 {
    <#
    .SYNOPSIS
    User activation of the Global Administrator role SHALL trigger an alert.

    .DESCRIPTION
    Runs the shared check Test-MtCisaActivationNotification with -GlobalAdminOnly.
    #>
    [MaesterTest(
        Id = 'CISA.MS.AAD.7.8',
        Title = 'User activation of the Global Administrator role SHALL trigger an alert.',
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P2', 'MS.AAD', 'MS.AAD.7.8'),
        Service = 'Graph',
        Author = 'soulemike',
        Contributor = ('michaelmsonne', 'JeanPhilippeGeorge')
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtCisaActivationNotification -GlobalAdminOnly
    if ($null -eq $result) { return $null }
    return $result
}