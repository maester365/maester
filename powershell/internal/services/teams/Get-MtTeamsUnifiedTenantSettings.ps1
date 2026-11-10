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

function Get-MtTeamsUnifiedSettingsAccessToken {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [object]$Context
    )

    $tenantId = [string]$Context.TenantId
    $clientId = '12128f48-ec9e-42f0-b203-ea49fb6af367'
    $scope = @('08ff1ce2-4973-4b08-86a3-ebed13badc7f/.default')
    $authority = "https://login.microsoftonline.com/$tenantId"
    $cacheKey = "$tenantId|$($Context.Environment)"

    if (-not ('Microsoft.Identity.Client.PublicClientApplicationBuilder' -as [type])) {
        $authenticationModule = Get-Module Microsoft.Graph.Authentication | Sort-Object Version -Descending | Select-Object -First 1
        if (-not $authenticationModule) {
            throw 'Microsoft.Graph.Authentication must be loaded before acquiring a Teams unified settings token.'
        }

        $dependencyFolder = if ($PSVersionTable.PSEdition -eq 'Core') { 'Core' } else { 'Desktop' }
        $msalPath = Join-Path $authenticationModule.ModuleBase "Dependencies\$dependencyFolder\Microsoft.Identity.Client.dll"
        if (-not (Test-Path -LiteralPath $msalPath)) {
            throw "Microsoft.Identity.Client.dll was not found at '$msalPath'."
        }
        $null = Add-Type -Path $msalPath -ErrorAction Stop
    }

    if (-not $__MtSession.TeamsAuthCache.ContainsKey('Clients')) {
        $__MtSession.TeamsAuthCache['Clients'] = @{}
    }

    $clients = $__MtSession.TeamsAuthCache['Clients']
    if (-not $clients.ContainsKey($cacheKey)) {
        $clients[$cacheKey] = [Microsoft.Identity.Client.PublicClientApplicationBuilder]::Create($clientId).
            WithAuthority($authority).
            WithRedirectUri('http://localhost').
            Build()
    }
    $application = $clients[$cacheKey]

    $accounts = @($application.GetAccountsAsync().GetAwaiter().GetResult())
    $account = $null
    if ($Context.Account) {
        $account = $accounts | Where-Object { $_.Username -eq [string]$Context.Account } | Select-Object -First 1
    }

    $result = $null
    if ($account) {
        try {
            $result = $application.AcquireTokenSilent($scope, $account).ExecuteAsync().GetAwaiter().GetResult()
        } catch [Microsoft.Identity.Client.MsalUiRequiredException] {
            Write-Verbose 'Silent token acquisition requires user interaction.'
        }
    }

    if (-not $result -and $__MtSession.TeamsUseDeviceCode) {
        $deviceCodeCallback = [System.Func[Microsoft.Identity.Client.DeviceCodeResult, System.Threading.Tasks.Task]] {
            param($deviceCode)
            Write-Information $deviceCode.Message -InformationAction Continue
            [System.Threading.Tasks.Task]::CompletedTask
        }
        $result = $application.AcquireTokenWithDeviceCode($scope, $deviceCodeCallback).ExecuteAsync().GetAwaiter().GetResult()
    } elseif (-not $result) {
        $interactiveRequest = $application.AcquireTokenInteractive($scope).WithUseEmbeddedWebView($false)
        if ($Context.Account) {
            $interactiveRequest = $interactiveRequest.WithLoginHint([string]$Context.Account)
        }
        $result = $interactiveRequest.ExecuteAsync().GetAwaiter().GetResult()
    }

    if (-not $result -or [string]::IsNullOrWhiteSpace($result.AccessToken)) {
        throw 'Microsoft identity platform returned no access token for Teams unified app settings.'
    }

    return $result.AccessToken
}
