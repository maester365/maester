<#
.SYNOPSIS
    Checks if Default Authorization Settings - Guest user access is set to '2af84b1e-32c8-42b7-82bc-daa82404023b'

.DESCRIPTION

    Represents role templateId for the role that should be granted to guest user.

    Queries policies/authorizationPolicy
    and returns the result of
     graph/policies/authorizationPolicy.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'

.EXAMPLE
    Test-MtEidscaAP07

    Returns the result of graph.microsoft.com/beta/policies/authorizationPolicy.guestUserRoleId -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'
#>

Function Test-MtEidscaAP07 {
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $tenantValue = $result.guestUserRoleId | Out-String -NoNewLine
    $testResult = $tenantValue -eq '2af84b1e-32c8-42b7-82bc-daa82404023b'

    if($testResult){
        $testResultMarkdown = "Well done. Your tenant has the recommended value of **'2af84b1e-32c8-42b7-82bc-daa82404023b'** for **policies/authorizationPolicy**"
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'2af84b1e-32c8-42b7-82bc-daa82404023b'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $tenantValue
}
