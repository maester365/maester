function Get-MtTenantContext {
    <#
    .SYNOPSIS
    Returns the facts about the connected tenant that decide which Maester tests apply.

    .DESCRIPTION
    The tenant context holds the tenant ID and name, tenant type (Workforce or External), cloud, the
    operating system Maester runs on, which services are connected, and the tenant's licences (service
    plan names, service plan IDs and SKU IDs). Invoke-Maester builds it once per run, records it in the
    results as TenantContext, and uses it to decide whether each test applies.

    Each fact comes from its own provider. A value set under Environment in the Maester config replaces
    the detected value: TenantType, Cloud, Licenses (a list of service plan names) and Services (a map
    of service name to true or false). A fact that cannot be detected is Unknown and never makes a test
    skip.

    .PARAMETER Service
    The services to check the connection of. Defaults to every service in the service registry.

    .PARAMETER Environment
    The Environment section of a Maester config, whose values replace detected ones.

    .EXAMPLE
    Get-MtTenantContext

    Shows the tenant type, cloud, connected services and licence state of the current connection.

    .LINK
    https://maester.dev/docs/commands/Get-MtTenantContext
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()]
        [string[]] $Service,

        [Parameter()]
        [AllowNull()]
        [object] $Environment
    )

    $registry = Get-MtServiceRegistry
    if (-not $Service) { $Service = @($registry.Services.Keys | Sort-Object) }
    $environment = if ($Environment) { $Environment } elseif ($__MtSession.MaesterConfig -and $__MtSession.MaesterConfig.PSObject.Properties['Environment']) { $__MtSession.MaesterConfig.Environment } else { $null }
    $forced = { param($name) if ($environment -and $environment.PSObject.Properties[$name] -and $null -ne $environment.$name -and "$($environment.$name)" -ne 'Auto') { $environment.$name } else { $null } }

    $graphConnected = Test-MtConnection -Service Graph -ErrorAction SilentlyContinue -WarningAction SilentlyContinue
    $mgContext = if ($graphConnected) { Get-MgContext } else { $null }

    # Services: probe each once; Environment.Services can force a value.
    $services = [ordered]@{}
    $probed = @{}
    foreach ($name in $Service) {
        $canonical = Resolve-MtServiceName -Name $name -Registry $registry
        if (-not $canonical) { continue }
        $probe = $registry.Services[$canonical].Probe
        if (-not $probed.ContainsKey($probe)) {
            $probed[$probe] = if ($probe -eq 'Graph') { [bool]$graphConnected } else {
                try { [bool](Test-MtConnection -Service $probe -ErrorAction SilentlyContinue -WarningAction SilentlyContinue) } catch { $false }
            }
        }
        $services[$canonical] = $probed[$probe]
    }
    $forcedServices = & $forced 'Services'
    if ($forcedServices) {
        foreach ($p in $forcedServices.PSObject.Properties) {
            $canonical = Resolve-MtServiceName -Name $p.Name -Registry $registry
            if ($canonical) { $services[$canonical] = [bool]$p.Value }
        }
    }

    # Organization: name and tenant type.
    $tenantName = $null
    $tenantType = 'Unknown'
    $tenantTypeSource = 'Unknown'
    if ($graphConnected) {
        try {
            $organization = @(Invoke-MtGraphRequest -RelativeUri 'organization' -ErrorAction Stop) | Select-Object -First 1
            $tenantName = $organization.displayName
            $tenantType = switch ($organization.tenantType) { 'AAD' { 'Workforce' } 'CIAM' { 'External' } default { 'Unknown' } }
            if ($tenantType -ne 'Unknown') { $tenantTypeSource = 'Detected' }
        } catch {
            Write-Verbose "Could not read the organization: $($_.Exception.Message)"
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
