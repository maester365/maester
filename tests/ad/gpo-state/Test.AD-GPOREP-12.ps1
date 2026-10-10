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
        Severity = 'Info',
        Category = 'Active Directory - GPO State',
        Product = 'Active Directory',
        Tag = 'AD.GPOState',
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
