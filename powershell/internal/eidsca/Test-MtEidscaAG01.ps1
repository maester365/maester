<#
.SYNOPSIS
    Checks if Authentication Method - General Settings - Manage migration is set to @('migrationComplete', '')

.DESCRIPTION

    The state of migration of the authentication methods policy from the legacy multifactor authentication and self-service password reset (SSPR) policies. In January 2024, the legacy multifactor authentication and self-service password reset policies will be deprecated and you'll manage all authentication methods here in the authentication methods policy. Use this control to manage your migration from the legacy policies to the new unified policy.

    Queries policies/authenticationMethodsPolicy
    and returns the result of
     graph/policies/authenticationMethodsPolicy.policyMigrationState -in @('migrationComplete', '')

.EXAMPLE
    Test-MtEidscaAG01

    Returns the result of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.policyMigrationState -in @('migrationComplete', '')
#>

function Test-MtEidscaAG01 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    
    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    [string]$tenantValue = $result.policyMigrationState
    $testResult = $tenantValue -in @('migrationComplete', '')
    $tenantValueNotSet = ($null -eq $tenantValue -or $tenantValue -eq "") -and @('migrationComplete', '') -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is one of the following values **@('migrationComplete', '')** for **policies/authenticationMethodsPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **@('migrationComplete', '')** for **policies/authenticationMethodsPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is one of the following values **@('migrationComplete', '')** for **policies/authenticationMethodsPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Info'

    return $tenantValue
}
