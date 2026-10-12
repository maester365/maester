function Test-MtCheckEidscaST08 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner is 'false'

    .DESCRIPTION
    Indicating whether or not a guest user can be an owner of groups, manage

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaST08
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.ST08',
        Title = 'Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to become Group Owner.',
        Product = 'entra',
        Feature = 'groups',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'T1098',
        Control = 'nist-800-53-r5:AC-6',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaST08
    return ($tenantValue -eq 'false')
}
