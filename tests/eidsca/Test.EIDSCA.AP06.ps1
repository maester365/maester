function Test-MtCheckEidscaAP06 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - User can join the tenant by email validation is 'false'

    .DESCRIPTION
    Controls whether users can join the tenant by email validation. To join, the user must have an email address in a domain which matches one of the verified domains in the tenant.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .allowEmailVerifiedUsersToJoinOrganization with Test-MtEidscaAP06
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP06',
        Title = 'Default Authorization Settings - User can join the tenant by email validation.',
        Severity = 'Medium',
        Category = 'EIDSCA',
        Product = 'Entra ID',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP06
    return ($tenantValue -eq 'false')
}
