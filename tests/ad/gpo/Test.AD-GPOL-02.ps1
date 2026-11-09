function Test-MtCheckADGPOL02 {
    <#
    .SYNOPSIS
    Disabled GPO link count should be retrievable

    .DESCRIPTION
    Runs the shared check Test-MtAdGpoDisabledLinkCount.
    .EXAMPLE
    Invoke-MtTest -Id AD-GPOL-02
    Run the disabled-link inventory through the native test engine.
    .LINK
    https://maester.dev/docs/tests/AD-GPOL-02
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
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Test-MtAdGpoDisabledLinkCount
    if ($null -eq $result) { return $null }
    return $result
}
