function Test-MtCheckEidscaPR01 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Password Rule Settings - Password Protection - Mode is 'Enforce'

    .DESCRIPTION
    If set to Enforce, users will be prevented from setting banned passwords and the attempt will be logged. If set to Audit, the attempt will only be logged.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaPR01
    and passes when it -eq 'Enforce'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.PR01',
        Title = 'Default Settings - Password Rule Settings - Password Protection - Mode.',
        Product = 'entra',
        RelatedProduct = 'ad',
        Feature = 'password-protection',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'High',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1110',
        Control = 'nist-800-53-r5:IA-5(1)',
        Service = 'Graph',
        License = 'AAD_PREMIUM',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaPR01
    return ($tenantValue -eq 'Enforce')
}
