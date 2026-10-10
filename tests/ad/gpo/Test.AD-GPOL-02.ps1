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
        Severity = 'Info',
        Category = 'Active Directory - Group Policy Links',
        Product = 'Active Directory',
        Tag = 'AD.GPO',
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
