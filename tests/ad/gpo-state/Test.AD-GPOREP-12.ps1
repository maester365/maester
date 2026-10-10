function Test-MtCheckADGPOREP12 {
    <#
    .SYNOPSIS
    GPO disabled link count should be retrievable

    .DESCRIPTION
    Runs the shared check Test-MtAdGpoDisabledLinkCount.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-12',
        Title = 'GPO disabled link count should be retrievable',
        Product = 'ad',
        Severity = 'Info',
        Service = 'ActiveDirectory',
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtAdGpoDisabledLinkCount
    if ($null -eq $result) { return $null }
    return $result
}
