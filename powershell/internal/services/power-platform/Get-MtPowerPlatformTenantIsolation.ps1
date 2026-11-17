function Get-MtPowerPlatformTenantIsolation {
    <#
    .SYNOPSIS
    Retrieves the Power Platform tenant isolation policy.

    .DESCRIPTION
    Returns the tenant isolation policy of the signed-in tenant, cached for the current test run. Returns $null when the
    policy has never been configured.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param()

    if ($__MtSession.PowerPlatformCache.ContainsKey('TenantIsolation')) {
        return $__MtSession.PowerPlatformCache['TenantIsolation']
    }

    $tenantId = (Get-AzContext -ErrorAction Stop).Tenant.Id
    $policy = Invoke-MtPowerPlatformRequest -RelativeUri "/providers/PowerPlatform.Governance/v1/tenants/$tenantId/tenantIsolationPolicy?api-version=2020-06-01"
    # Windows PowerShell keeps a null response body as the text "null".
    if ($policy -is [string]) {
        $policy = $null
    }

    $__MtSession.PowerPlatformCache['TenantIsolation'] = $policy
    return $policy
}
