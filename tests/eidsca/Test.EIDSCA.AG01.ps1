function Test-MtCheckEidscaAG01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - General Settings - Manage migration is one of the following values @('migrationComplete', '')

    .DESCRIPTION
    The state of migration of the authentication methods policy from the legacy multifactor authentication and self-service password reset (SSPR) policies. In January 2024, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
    .policyMigrationState with Test-MtEidscaAG01
    and passes when it -in @('migrationComplete', '').
    #>
    [MaesterTest(
        Id = 'EIDSCA.AG01',
        Title = 'Authentication Method - General Settings - Manage migration.',
        Severity = 'High',
        Category = 'EIDSCA',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAG01
    return ($tenantValue -in @('migrationComplete', ''))
}
