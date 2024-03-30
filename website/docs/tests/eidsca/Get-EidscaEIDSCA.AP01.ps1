<#
.SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset is set to 'true'

.DESCRIPTION

    Designates whether users in this directory can reset their own password.

    Queries policies/authorizationPolicy
    and checks if allowedToUseSSPR is set to 'true'

.EXAMPLE
    Get-EidscaEIDSCA.AP01

    Returns the value of allowedToUseSSPR at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP01 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.allowedToUseSSPR -eq 'true') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
