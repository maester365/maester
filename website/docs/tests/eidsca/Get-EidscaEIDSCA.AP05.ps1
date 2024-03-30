<#
.SYNOPSIS
    Checks if Default Authorization Settings - Sign-up for email based subscription is set to 'false'

.DESCRIPTION

    Indicates whether users can sign up for email based subscriptions.

    Queries policies/authorizationPolicy
    and checks if allowedToSignUpEmailBasedSubscriptions is set to 'false'

.EXAMPLE
    Get-EidscaEIDSCA.AP05

    Returns the value of allowedToSignUpEmailBasedSubscriptions at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP05 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.allowedToSignUpEmailBasedSubscriptions -eq 'false') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
