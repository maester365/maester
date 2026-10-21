function Test-MtEidscaAP12 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - Default User Role Permissions - Allowed to create Tenants is set to 'false'

    .DESCRIPTION

    Restricts the creation of Entra ID (Azure AD) tenants to the global administrator or tenant creator roles. Anyone who creates a tenant will become the global administrator for that tenant.

    Queries policies/authorizationPolicy
    and returns the tenant value of
    graph/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateTenants

    The native test EIDSCA.AP12 passes when this value -eq 'false'.

    .EXAMPLE
    Test-MtEidscaAP12

    Returns the tenant value of graph.microsoft.com/beta/policies/authorizationPolicy.defaultUserRolePermissions.allowedToCreateTenants
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $rawValue = $result.defaultUserRolePermissions.allowedToCreateTenants
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
