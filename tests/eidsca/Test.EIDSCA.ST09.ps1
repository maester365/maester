function Test-MtCheckEidscaST09 {
    <#
    .SYNOPSIS
    Checks if Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content is 'True'

    .DESCRIPTION
    Indicating whether or not a guest user can have access to Microsoft 365 groups content. This setting does not require an Azure Active Directory Premium P1 license.

    Reads the tenant value of
    https://graph.microsoft.com/beta/settings
    .values with Test-MtEidscaST09
    and passes when it -eq 'True'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.ST09',
        Title = 'Default Settings - Classification and M365 Groups - M365 groups - Allow Guests to have access to groups content.',
        Product = 'entra',
        Feature = 'groups',
        Area = 'external-access',
        ResourceType = 'Tenant',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = ('nist-800-53-r5:AC-6', 'nist-800-53-r5:AC-21'),
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaST09
    return ($tenantValue -eq 'True')
}
