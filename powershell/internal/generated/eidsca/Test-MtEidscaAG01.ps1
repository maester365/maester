function Test-MtEidscaAG01 {
    <#
    .SYNOPSIS
    Checks if Authentication Method - General Settings - Manage migration is set to @('migrationComplete', '')

    .DESCRIPTION

    The state of migration from the legacy multifactor authentication and self-service password reset (SSPR) policies to the Authentication methods policy. Legacy policies are respected in the premigration and migrationInProgress states and ignored in the migrationComplete state.

    Queries policies/authenticationMethodsPolicy
    and returns the tenant value of
    graph/policies/authenticationMethodsPolicy.policyMigrationState

    The native test EIDSCA.AG01 passes when this value -in @('migrationComplete', '').

    .EXAMPLE
    Test-MtEidscaAG01

    Returns the tenant value of graph.microsoft.com/beta/policies/authenticationMethodsPolicy.policyMigrationState
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authenticationMethodsPolicy" -ApiVersion beta

    $rawValue = $result.policyMigrationState
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -in @('migrationComplete', '')
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and @('migrationComplete', '') -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is one of the following values **@('migrationComplete', '')** for **policies/authenticationMethodsPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **@('migrationComplete', '')** for **policies/authenticationMethodsPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is one of the following values **@('migrationComplete', '')** for **policies/authenticationMethodsPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Low'

    return $tenantValue
}
