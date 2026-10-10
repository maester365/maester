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
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaST08
    return ($tenantValue -eq 'false')
}
