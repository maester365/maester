function Get-MtPowerPlatformDlpPolicy {
    <#
    .SYNOPSIS
    Retrieves the tenant-level Power Platform data loss prevention (DLP) policies.

    .DESCRIPTION
    Returns one object per policy with its scope: AllEnvironments, OnlyEnvironments or ExceptEnvironments, and the
    names of the environments the scope lists, cached for the current test run. A policy without an environment filter
    applies to every environment.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    if ($__MtSession.PowerPlatformCache.ContainsKey('DlpPolicies')) {
        return $__MtSession.PowerPlatformCache['DlpPolicies']
    }

    $response = Invoke-MtPowerPlatformRequest -RelativeUri '/providers/Microsoft.BusinessAppPlatform/scopes/admin/apiPolicies?api-version=2016-11-01'
    if ($null -eq $response -or $null -eq $response.PSObject.Properties['value']) {
        throw 'The Power Platform data policy API did not return a policy collection.'
    }

    $policies = @(foreach ($policy in @($response.value)) {
            $filter = $policy.properties.definition.constraints.environmentFilter1
            $scope = 'AllEnvironments'
            $environmentNames = @()
            if ($null -ne $filter) {
                if ($filter.parameters.filterType -eq 'include') {
                    $scope = 'OnlyEnvironments'
                }
                else {
                    $scope = 'ExceptEnvironments'
                }

                $environmentNames = @($filter.parameters.environments | Where-Object { $_ } | ForEach-Object { $_.name })
            }

            [pscustomobject]@{
                Name         = $policy.name
                DisplayName  = $policy.properties.displayName
                Scope        = $scope
                Environments = $environmentNames
            }
        })

    $__MtSession.PowerPlatformCache['DlpPolicies'] = $policies
    return $policies
}
