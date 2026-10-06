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
        Severity = 'High',
        Category = 'CISA',
        Tag = ('Entra ID P2', 'MS.AAD', 'MS.AAD.7.9'),
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