function Test-MtCheckEidscaAP12 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create Tenants is 'false'

    .DESCRIPTION
    Restricts the creation of Entra ID (Azure AD) tenants to the global administrator or tenant creator roles. Anyone who creates a tenant will become the global administrator for that tenant.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authorizationPolicy
    .defaultUserRolePermissions.allowedToCreateTenants with Test-MtEidscaAP12
    and passes when it -eq 'false'.
    #>
    [MaesterTest(
        Id = 'EIDSCA.AP12',
        Title = 'Default Authorization Settings - Default User Role Permissions - Allowed to create Tenants.',
        Product = 'entra',
        Feature = 'user-settings',
        Area = 'access-control',
        ResourceType = 'Tenant',
        Severity = 'Medium',
        UserImpact = 'Medium',
        ImplementationCost = 'Low',
        Mitre = 'None',
        Control = 'nist-800-53-r5:AC-6(10)',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAP12
    return ($tenantValue -eq 'false')
}
