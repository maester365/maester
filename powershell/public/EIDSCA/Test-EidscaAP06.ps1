<#
.SYNOPSIS
    Checks if Default Authorization Settings - User can joint the tenant by email validation is set to 'false'

.DESCRIPTION

    Controls whether users can join the tenant by email validation. To join, the user must have an email address in a domain which matches one of the verified domains in the tenant.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization -eq 'false'

.EXAMPLE
    Test-EidscaAP06

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowEmailVerifiedUsersToJoinOrganization -eq 'false'
#>

Function Test-EidscaAP06 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $tenantValue = $result.allowEmailVerifiedUsersToJoinOrganization
    $testResult = $tenantValue -eq 'false'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'false'** for **policies/authorizationPolicy**"
    }
    else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
