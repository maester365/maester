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
        $deviceCodeType = 'Microsoft.Identity.Client.DeviceCodeResult' -as [type]
        if (-not $deviceCodeType) {
            throw 'Microsoft.Identity.Client.DeviceCodeResult is unavailable for Teams device-code authentication.'
        }

        $messageSource = [System.Threading.Tasks.TaskCompletionSource[string]]::new([System.Threading.Tasks.TaskCreationOptions]::RunContinuationsAsynchronously)
        $deviceCodeCallback = Get-MtTeamsUnifiedSettingsDeviceCodeCallback -DeviceCodeType $deviceCodeType -MessageSource $messageSource
        $tokenTask = $application.AcquireTokenWithDeviceCode($scope, $deviceCodeCallback).ExecuteAsync()
        $waitTask = [System.Threading.Tasks.Task]::WhenAny(
            [System.Threading.Tasks.Task[]]@($tokenTask, $messageSource.Task)
        )
        $null = $waitTask.GetAwaiter().GetResult()
        if ($messageSource.Task.IsCompleted) {
            Write-Information $messageSource.Task.GetAwaiter().GetResult() -InformationAction Continue
        }
        $result = $tokenTask.GetAwaiter().GetResult()
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
