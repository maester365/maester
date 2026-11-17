function Get-MtPowerPlatformEnvironment {
    <#
    .SYNOPSIS
    Retrieves the Power Platform environments of the tenant.

    .DESCRIPTION
    Returns one object per environment with its name, display name, type and whether it is the default environment,
    cached for the current test run.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param()

    if ($__MtSession.PowerPlatformCache.ContainsKey('Environments')) {
        return $__MtSession.PowerPlatformCache['Environments']
    }

    $response = Invoke-MtPowerPlatformRequest -RelativeUri '/providers/Microsoft.BusinessAppPlatform/scopes/admin/environments?api-version=2023-06-01'
    $environments = @(foreach ($environment in @($response.value)) {
            [pscustomobject]@{
                Name            = $environment.name
                DisplayName     = $environment.properties.displayName
                IsDefault       = $environment.properties.isDefault -eq $true
                EnvironmentType = $environment.properties.environmentSku
            }
        })

    $__MtSession.PowerPlatformCache['Environments'] = $environments
    return $environments
}
