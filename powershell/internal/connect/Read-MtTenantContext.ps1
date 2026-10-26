function Read-MtTenantContext {
    <#
    .SYNOPSIS
    Reads the tenant context in steps, and says after each step what it found.

    .DESCRIPTION
    The work of Get-MtTenantContext. Some of the facts need a request to a service (the organization, the
    licences, and for some services whether the token still works), so reading all of them takes a second
    or more. -OnStep is called as each part is known, so that a caller with a display can show the account
    first and fill in the rest as it arrives:

      Account       TenantId, Account, AuthType, Graph    from the Graph session, without a request
      Organization  TenantName, PrimaryDomain             after the organization was read
      Service       Name, Connected                       once for each service that was checked

    A step that throws is ignored: the display must not cost the run its tenant context.

    .PARAMETER Service
    The services to check the connection of. Defaults to every service in the service registry.

    .PARAMETER Environment
    The Environment section of a Maester config, whose values replace detected ones.

    .PARAMETER OnStep
    Called with the name of the step and a hashtable of what it found.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string[]] $Service,

        [Parameter()]
        [AllowNull()]
        [object] $Environment,

        [Parameter()]
        [AllowNull()]
        [scriptblock] $OnStep
    )

    $registry = Get-MtServiceRegistry
    if (-not $Service) { $Service = @($registry.Services.Keys | Sort-Object) }
    $environment = if ($Environment) { $Environment } elseif ($__MtSession.MaesterConfig -and $__MtSession.MaesterConfig.PSObject.Properties['Environment']) { $__MtSession.MaesterConfig.Environment } else { $null }
    $forced = { param($name) if ($environment -and $environment.PSObject.Properties[$name] -and $null -ne $environment.$name -and "$($environment.$name)" -ne 'Auto') { $environment.$name } else { $null } }

    # A step that cannot be shown must not cost the run its tenant context.
    $report = $OnStep
    $step = {
        param($name, $data)
        if (-not $report) { return }
        try { & $report $name $data } catch { Write-Debug "Tenant context step ${name}: $($_.Exception.Message)" }
    }

    $graphConnected = Test-MtConnection -Service Graph -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    $mgContext = if ($graphConnected) { Get-MgContext } else { $null }

    # What the Graph session knows without a request: the tenant ID and the account.
    & $step 'Account' @{ TenantId = if ($mgContext) { $mgContext.TenantId } else { $null }; Account = if ($mgContext) { $mgContext.Account } else { $null }; AuthType = if ($mgContext) { [string]$mgContext.AuthType } else { $null }; Graph = [bool]$graphConnected }

    # Organization: name and tenant type.
    $tenantName = $null
    $primaryDomain = $null
    $tenantType = 'Unknown'
    $tenantTypeSource = 'Unknown'
    if ($graphConnected) {
        try {
            $organization = @(Invoke-MtGraphRequest -RelativeUri 'organization' -ErrorAction Stop) | Select-Object -First 1
            $tenantName = $organization.displayName
            $primaryDomain = @($organization.verifiedDomains | Where-Object { $_.isDefault } | Select-Object -First 1).name
            $tenantType = switch ($organization.tenantType) { 'AAD' { 'Workforce' } 'CIAM' { 'External' } default { 'Unknown' } }
            if ($tenantType -ne 'Unknown') { $tenantTypeSource = 'Detected' }
        } catch {
            Write-Verbose "Could not read the organization: $($_.Exception.Message)"
        }
    }
    & $step 'Organization' @{ TenantName = $tenantName; PrimaryDomain = $primaryDomain }

    # Services: probe each once; Environment.Services can force a value. Some probes ask the service
    # whether its token still works, so each answer is reported as it comes.
    $services = [ordered]@{}
    $probed = @{}
    foreach ($name in $Service) {
        $canonical = Resolve-MtServiceName -Name $name -Registry $registry
        if (-not $canonical) { continue }
        $probe = $registry.Services[$canonical].Probe
        if (-not $probed.ContainsKey($probe)) {
            $probed[$probe] = if ($probe -eq 'Graph') { [bool]$graphConnected } elseif ($registry.Services[$canonical].ContainsKey('Pack')) { Test-MtPackConnection -Service $canonical } else {
                try { [bool](Test-MtConnection -Service $probe -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) } catch { $false }
            }
        }
        $services[$canonical] = $probed[$probe]
        & $step 'Service' @{ Name = $canonical; Connected = [bool]$probed[$probe] }
    }
    $forcedServices = & $forced 'Services'
    if ($forcedServices) {
        foreach ($p in $forcedServices.PSObject.Properties) {
            $canonical = Resolve-MtServiceName -Name $p.Name -Registry $registry
            if ($canonical) { $services[$canonical] = [bool]$p.Value }
        }
    }

    $forcedTenantType = & $forced 'TenantType'
    if ($forcedTenantType) { $tenantType = [string]$forcedTenantType; $tenantTypeSource = 'Config' }

    # Cloud, from the Graph environment.
    $cloud = 'Unknown'
    $cloudSource = 'Unknown'
    if ($mgContext) {
        $cloud = switch ($mgContext.Environment) {
            'Global' { 'Commercial' } 'USGov' { 'GCCHigh' } 'USGovDoD' { 'DoD' } 'China' { 'China' } default { 'Unknown' }
        }
        # GCC uses the worldwide endpoint and cannot be told apart from Commercial through Graph.
        $cloudSource = if ($cloud -eq 'Commercial') { 'Assumed' } elseif ($cloud -ne 'Unknown') { 'Detected' } else { 'Unknown' }
    }
    $forcedCloud = & $forced 'Cloud'
    if ($forcedCloud) { $cloud = [string]$forcedCloud; $cloudSource = 'Config' }

    # Licences: three-valued. Unknown never skips a test.
    $licenses = [ordered]@{ State = 'Unknown'; ServicePlanNames = @(); ServicePlanIds = @(); SkuIds = @(); Source = 'Unknown' }
    $forcedLicenses = & $forced 'Licenses'
    if ($forcedLicenses) {
        $licenses.State = 'Known'
        $licenses.ServicePlanNames = @($forcedLicenses)
        $licenses.Source = 'Config'
    } elseif ($graphConnected) {
        try {
            $skus = @(Invoke-MtGraphRequest -RelativeUri 'subscribedSkus' -ErrorAction Stop | Where-Object { $_.capabilityStatus -eq 'Enabled' })
            $plans = @($skus | ForEach-Object { $_.servicePlans })
            $licenses.State = 'Known'
            $licenses.ServicePlanNames = @($plans | ForEach-Object { $_.servicePlanName } | Where-Object { $_ } | Sort-Object -Unique)
            $licenses.ServicePlanIds = @($plans | ForEach-Object { $_.servicePlanId } | Where-Object { $_ } | Sort-Object -Unique)
            $licenses.SkuIds = @($skus | ForEach-Object { $_.skuId } | Where-Object { $_ } | Sort-Object -Unique)
            $licenses.Source = 'Detected'
        } catch {
            Write-Verbose "Could not read the tenant's licences: $($_.Exception.Message)"
        }
    }

    $platform = if ($IsWindows) { 'Windows' } elseif ($IsMacOS) { 'MacOS' } elseif ($IsLinux) { 'Linux' } else { 'Unknown' }

    [pscustomobject]@{
        PSTypeName       = 'Maester.TenantContext'
        TenantId         = if ($mgContext) { $mgContext.TenantId } else { $null }
        TenantName       = $tenantName
        PrimaryDomain    = if ($primaryDomain) { [string]$primaryDomain } else { $null }
        TenantType       = $tenantType
        TenantTypeSource = $tenantTypeSource
        Cloud            = $cloud
        CloudSource      = $cloudSource
        Platform         = $platform
        Services         = [pscustomobject]$services
        Licenses         = [pscustomobject]$licenses
        AuthType         = if ($mgContext) { [string]$mgContext.AuthType } else { $null }
        Account          = if ($mgContext) { $mgContext.Account } else { $null }
        Scopes           = if ($mgContext) { @($mgContext.Scopes) } else { @() }
    }
}
