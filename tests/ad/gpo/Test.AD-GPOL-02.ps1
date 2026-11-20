function Test-MtCheckADGPOL02 {
    <#
    .SYNOPSIS
    Inventories disabled GPO links without making a risk judgement.

    .DESCRIPTION
    Runs the shared check Test-MtAdGpoDisabledLinkCount.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOL-02'

    Inventories disabled GPO links for review without treating them as a failure.

    .LINK
    https://maester.dev/docs/tests/AD-GPOL-02
    #>
    [MaesterTest(
        Id                 = 'AD-GPOL-02',
        Title              = 'Disabled GPO link inventory',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'infrastructure',
        ResourceType       = 'GroupPolicy',
        Severity           = 'Info',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtAdGpoDisabledLinkCount
}
