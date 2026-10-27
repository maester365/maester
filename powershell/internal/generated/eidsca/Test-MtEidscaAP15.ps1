function Test-MtEidscaAP15 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create agent identity blueprints is set to 'false'

    .DESCRIPTION

    Controls whether users can create agent identity blueprints and their associated principals through the default user role. Blueprint creators become owners and can create agent identities for their blueprints. Allowing creation does not itself grant access to organizational data.

    Queries policies/authorizationPolicy
    and returns the tenant value of
    graph/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints

    The native test EIDSCA.AP15 passes when this value -eq 'false'.

    .EXAMPLE
    Test-MtEidscaAP15

    Returns the tenant value of graph.microsoft.com/beta/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $rawValue = $result.defaultUserRolePermissions.allowedToCreateAgentIdentityBlueprints
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
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'Medium'

    return $tenantValue
}
