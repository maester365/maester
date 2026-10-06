function Test-MtCheckEidscaAP10 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create Apps is 'false'

    .DESCRIPTION
    Controls if non-admin users may register custom-developed applications for use within this directory.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .defaultUserRolePermissions.allowedToCreateApps with Test-MtEidscaAP10
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP10',
        Title = 'Default Authorization Settings - Default User Role Permissions - Allowed to create Apps.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP10
    return ($tenantValue -eq 'false')
}
