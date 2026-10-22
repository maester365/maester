function Test-MtCheckEidscaAG01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - General Settings - Manage migration is one of the following values @('migrationComplete', '')

    .DESCRIPTION
    The state of migration from the legacy multifactor authentication and self-service password reset (SSPR) policies to the Authentication methods policy. Legacy policies are respected in the premigration and migrationInProgress states and ignored in the migrationComplete state.

    Reads the tenant value of
    https://graph.microsoft.com/beta/policies/authenticationMethodsPolicy
    .policyMigrationState with Test-MtEidscaAG01
    and passes when it -in @('migrationComplete', '').
    #>
    [MaesterTest(
        Id = 'EIDSCA.AG01',
        Title = 'Authentication Method - General Settings - Manage migration.',
        Product = 'entra',
        Feature = 'authentication-methods',
        Area = 'authentication',
        ResourceType = 'Tenant',
        Severity = 'Info',
        Mitre = 'None',
        Control = 'nist-800-53-r5:CM-7',
        Service = 'Graph',
        Author = 'Cloud-Architekt'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $tenantValue = Test-MtEidscaAG01
    return ($tenantValue -in @('migrationComplete', ''))
}
