function Test-MtEidscaAP08 {
    <#
    .SYNOPSIS
    Checks if Default Authorization Settings - User consent assignments match the restricted or Microsoft recommended baseline is set to '0'

    .DESCRIPTION

    Counts user consent assignments outside microsoft-user-default-low and microsoft-user-default-recommended. Either accepted policy or both passes. An explicit empty assignment collection or only resource-specific consent assignments passes because no default ManagePermissionGrantsForSelf policy is assigned. Missing or null assignment data is skipped. The legacy unrestricted policy fails, including when mixed with other policies. Other user consent policies, including custom policies and mail-client exceptions, require manual review and are skipped unless the legacy policy is also assigned. A pass confirms assignment compliance only; this check does not evaluate policy conditions, other consent authorization mechanisms, or existing grants.

    Queries policies/authorizationPolicy
    and returns the tenant value of
    graph/policies/authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole

    The native test EIDSCA.AP08 passes when this value -eq '0'.

    .EXAMPLE
    Test-MtEidscaAP08

    Returns the tenant value of graph.microsoft.com/beta/policies/authorizationPolicy.permissionGrantPolicyIdsAssignedToDefaultUserRole
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $result = Invoke-MtGraphRequest -RelativeUri "policies/authorizationPolicy" -ApiVersion beta

    $rawValue = $result.permissionGrantPolicyIdsAssignedToDefaultUserRole | Where-Object { $_ -like 'ManagePermissionGrantsForSelf.*' -and $_ -notin @('ManagePermissionGrantsForSelf.microsoft-user-default-low', 'ManagePermissionGrantsForSelf.microsoft-user-default-recommended') } | Measure-Object | Select-Object -ExpandProperty Count
    [string]$tenantValue = $rawValue
    $testResult = $tenantValue -eq '0'
    $tenantValueNotSet = ($null -eq $rawValue -or $rawValue -eq "") -and '0' -notlike '*$null*'

    if($testResult){
        $testResultMarkdown = "Well done. The configuration in your tenant and recommended value is **'0'** for **policies/authorizationPolicy**"
    } elseif ($tenantValueNotSet) {
        $testResultMarkdown = "Your tenant is **not configured explicitly**.`n`nThe recommended value is **'0'** for **policies/authorizationPolicy**. It seems that you are using a default value by Microsoft. We recommend to set the setting value explicitly since non set values could change depending on what Microsoft decides the current default should be."
    } else {
        $testResultMarkdown = "Your tenant is configured as **$($tenantValue)**.`n`nThe recommended value is **'0'** for **policies/authorizationPolicy**"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown -Severity 'High'

    return $tenantValue
}
