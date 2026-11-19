function Test-MtCheckADGPOREP12 {
    <#
    .SYNOPSIS
    Inventories disabled GPO links.
    .DESCRIPTION
    Uses Test-MtAdGpoDisabledLinkCount to count disabled links and list their policies and containers for review.
    #>
    [MaesterTest(
        Id = 'AD-GPOREP-12', Title = 'Review disabled GPO links',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'GroupPolicy', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    return Test-MtAdGpoDisabledLinkCount -Investigate
}
