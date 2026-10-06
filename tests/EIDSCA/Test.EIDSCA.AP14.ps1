function Test-MtCheckEidscaAP14 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to read other users is 'true'

    .DESCRIPTION
    Prevents all non-admins from reading user information from the directory. This flag doesn't prevent reading user information in other Microsoft services like Exchange Online.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .defaultUserRolePermissions.allowedToReadOtherUsers with Test-MtEidscaAP14
    and passes when it -eq 'true'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP14',
        Title = 'Default Authorization Settings - Default User Role Permissions - Allowed to read other users.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP14
    return ($tenantValue -eq 'true')
}
