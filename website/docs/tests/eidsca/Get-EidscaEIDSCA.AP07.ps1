<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest user access is set to '2af84b1e-32c8-42b7-82bc-daa82404023b'

.DESCRIPTION

    Represents role templateId for the role that should be granted to guest user.

    Queries policies/authorizationPolicy
    and checks if guestUserRoleId is set to '2af84b1e-32c8-42b7-82bc-daa82404023b'

.EXAMPLE
    Get-EidscaEIDSCA.AP07

    Returns the value of guestUserRoleId at policies/authorizationPolicy
#>

Function Get-EidscaEIDSCA.AP07 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    if($result.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b') {
        return $true
    } else {
        return $false
    }

    Add-MtTestResultDetail
}
