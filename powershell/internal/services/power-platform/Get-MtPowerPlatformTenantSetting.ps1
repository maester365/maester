function Get-MtPowerPlatformTenantSetting {
    <#
    .SYNOPSIS
    Retrieves the Power Platform tenant settings.

    .DESCRIPTION
    Returns the tenant settings object of the Power Platform admin API, cached for the current test run.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param()

    if ($__MtSession.PowerPlatformCache.ContainsKey('TenantSettings')) {
        return $__MtSession.PowerPlatformCache['TenantSettings']
    }

    $settings = Invoke-MtPowerPlatformRequest -Method Post -RelativeUri '/providers/Microsoft.BusinessAppPlatform/listTenantSettings?api-version=2023-06-01'
    if ($null -eq $settings) {
        throw 'The Power Platform admin API returned no tenant settings.'
    }

    $__MtSession.PowerPlatformCache['TenantSettings'] = $settings
    return $settings
}
