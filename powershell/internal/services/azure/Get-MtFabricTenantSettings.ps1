function Get-MtFabricTenantSettings {
    <#
    .SYNOPSIS
    Retrieves tenant settings from the Microsoft Fabric admin API.

    .DESCRIPTION
    Uses the active Azure context to acquire a Fabric-audience access token and returns the tenant setting records.
    #>
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Returns the full collection of Fabric tenant settings.')]
    [OutputType([object[]])]
    param()

    if ($__MtSession.FabricCache.ContainsKey('TenantSettings')) {
        return $__MtSession.FabricCache['TenantSettings']
    }

    $accessToken = Get-AzAccessToken -ResourceUrl 'https://api.fabric.microsoft.com' -AsSecureString -ErrorAction Stop
    if (-not $accessToken.Token) {
        throw 'The connected Azure context did not return a Microsoft Fabric access token.'
    }

    $requestUri = 'https://api.fabric.microsoft.com/v1/admin/tenantsettings'
    $settings = [System.Collections.Generic.List[object]]::new()
    while (-not [string]::IsNullOrEmpty($requestUri)) {
        $response = Invoke-RestMethod -Method Get `
            -Uri $requestUri `
            -Authentication Bearer `
            -Token $accessToken.Token `
            -ErrorAction Stop

        foreach ($setting in @($response.value)) {
            if ($null -ne $setting) {
                $settings.Add($setting)
            }
        }

        $requestUri = $response.continuationUri
    }

    $settings = $settings.ToArray()
    $__MtSession.FabricCache['TenantSettings'] = $settings
    return $settings
}
