function Get-MtTeamsUnifiedTenantSettings {
    [CmdletBinding()]
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'The Teams API returns a collection of settings.')]
    param()

    $context = Get-MgContext -ErrorAction Stop
    if (-not $context) {
        throw 'A Microsoft Graph context is required to retrieve Teams unified app settings.'
    }

    $tenantId = [string]$context.TenantId
    if ([string]::IsNullOrWhiteSpace($tenantId)) {
        throw 'The Microsoft Graph context does not include a tenant ID.'
    }

    if (($context.Environment -and $context.Environment -ne 'Global') -or
        $__MtSession.TeamsEnvironmentName -in @('TeamsChina', 'TeamsGCCH', 'TeamsDOD')) {
        return $null
    }
    if ($context.AuthType -ne 'Delegated') {
        return $null
    }

    $cacheKey = "UnifiedAppSettings:$tenantId"
    if ($__MtSession.TeamsCache.ContainsKey($cacheKey)) {
        return $__MtSession.TeamsCache[$cacheKey]
    }

    $accessToken = Get-MtTeamsUnifiedSettingsAccessToken -Context $context
    $response = Invoke-RestMethod `
        -Uri 'https://substrate.office.com/AdminAppCatalog/ps/v2/admin/unifiedApp/settings' `
        -Method Get `
        -Headers @{ Authorization = "Bearer $accessToken" } `
        -ErrorAction Stop

    if ($null -eq $response) {
        throw 'The Teams unified app settings API returned an empty response.'
    }

    $settings = if ($response.PSObject.Properties['value']) {
        @($response.value)
    } else {
        @($response)
    }

    foreach ($setting in $settings) {
        if ($null -eq $setting -or
            $null -eq $setting.PSObject.Properties['SettingName'] -or
            $null -eq $setting.PSObject.Properties['SettingValue']) {
            throw 'The Teams unified app settings API returned a setting without SettingName or SettingValue.'
        }
    }

    $__MtSession.TeamsCache[$cacheKey] = $settings
    return $settings
}
