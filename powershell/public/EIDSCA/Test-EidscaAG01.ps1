<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Manage migration is set to 'migrationComplete'

.DESCRIPTION

    The state of migration of the authentication methods policy from the legacy multifactor authentication and self-service password reset (SSPR) policies. In January 2024, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy.

    Queries policies/authenticationMethodsPolicy
    and returns the result of
     graph/policies/authenticationMethodsPolicy.policyMigrationState -eq 'migrationComplete'

.EXAMPLE
    Test-EidscaAG01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.policyMigrationState -eq 'migrationComplete'
#>

Function Test-EidscaAG01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    $testResult = $result.policyMigrationState -eq 'migrationComplete'

    Add-MtTestResultDetail -Result $testResult
}
