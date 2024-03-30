<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest user access is set to '2af84b1e-32c8-42b7-82bc-daa82404023b'

.DESCRIPTION

    Represents role templateId for the role that should be granted to guest user.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'

.EXAMPLE
    Test-EidscaAP07

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'
#>

Function Test-EidscaAP07 {
    [CmdletBinding()]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $testResult = $result.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'

    Add-MtTestResultDetail -Result $testResult
}
