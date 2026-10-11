function Test-MtCheckADGPOL02 {
    <#
    .SYNOPSIS
    Disabled GPO link count should be retrievable

    .DESCRIPTION
    Runs the shared check Test-MtAdGpoDisabledLinkCount.
    #>
    [MaesterTest(
        Id = 'AD-GPOL-02',
        Title = 'Disabled GPO link count should be retrievable',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'infrastructure',
        ResourceType = 'GroupPolicy',
        Severity = 'Info',
        Mitre = 'None',
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
