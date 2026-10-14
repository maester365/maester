function Test-MtEidscaAP01 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Enabled Self service password reset for administrators is set to 'false'

    .DESCRIPTION

    Indicates whether administrators of the tenant can use the Self-Service Password Reset (SSPR). The policy applies to some critical critical roles in Microsoft Entra ID.

    Queries policies/authorizationPolicy
    and returns the tenant value of
    graph/policies/authorizationPolicy.allowedToUseSSPR

    The native test EIDSCA.AP01 passes when this value -eq 'false'.

    .EXAMPLE
    Test-MtEidscaAP01

    Returns the tenant value of graph.microsoft.com/beta/policies/authorizationPolicy.allowedToUseSSPR
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $rawValue = $result.allowedToUseSSPR
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq 'false'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and 'false' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'false'** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'false'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Info'

    return $tenantValue
}
