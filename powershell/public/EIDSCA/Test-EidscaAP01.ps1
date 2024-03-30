<#
.SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset is set to 'true'

.DESCRIPTION

    Designates whether users in this directory can reset their own password.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.allowedToUseSSPR -eq 'true'

.EXAMPLE
    Test-EidscaAP01

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToUseSSPR -eq 'true'
#>

Function Test-EidscaAP01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.allowedToUseSSPR -eq 'true'

    Add-MtTestResultDetail -Result $testResult
}
