function Register-MtPackService {
    <#
    .SYNOPSIS
    Adds the connectors of the packs that passed the loader gate to the service registry (Maester Packs design, section 6.3).

    .DESCRIPTION
    Each connector becomes a service entry with Probe set to its own service name, so everything the engine
    does with a service works for it unchanged: [MaesterTest(Service = 'CNT.GoogleWorkspace')] validates,
    the gate gives Skipped with ServiceNotConnected (or NotRun with OptInServiceNotConnected when the
    connector says OptIn), and a test whose pack is missing gets ServiceNotRegistered. The entry also keeps
    Pack (the pack row), Connector (its manifest entry), DisplayName and Platform.

    The registry is rebuilt from the given pack set each time, so a pack that is no longer installed or
    allowed loses its services. Returns the service names registered.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $PackSet
    )

    $services = @{}
    foreach ($pack in ($PackSet | Where-Object { $_.Status -eq 'Ready' -and $_.Manifest })) {
        foreach ($c in $pack.Manifest.Connectors) {
            $name = [string]$c.Service
            if ($services.ContainsKey($name)) { Write-Warning "The service $name is provided by both $($services[$name].Pack.Id) and $($pack.Id); the connector of $($services[$name].Pack.Id) is used."; continue }
            $services[$name] = @{
                Probe          = $name
                OptIn          = [bool]($c.PSObject.Properties['OptIn'] -and $c.OptIn)
                RunspaceBound  = $true
                LegacySkipCode = 'Custom'
                Aliases        = @()
                Pack           = $pack
                Connector      = $c
                DisplayName    = if ($c.PSObject.Properties['DisplayName'] -and $c.DisplayName) { [string]$c.DisplayName } else { $name }
                Platform       = if ($c.PSObject.Properties['Platform'] -and $c.Platform) { [string]$c.Platform } else { $null }
            }
        }
    }
    $script:__MtPackServices = $services
    $script:__MtLayeredServiceRegistry = $null
    [string[]]@($services.Keys | Sort-Object)
}

function Initialize-MtPackSet {
    <#
    .SYNOPSIS
    Runs the loader gate for the current folder's packs and registers their connectors; returns the pack set.

    .DESCRIPTION
    Used by the commands that reach pack connectors outside a run (Connect-Maester, Disconnect-Maester,
    Test-MtConnection, Get-MtTenantContext, Get-MtConnector). The config and lock file are found from the
    current folder, as Invoke-Maester finds them. Any failure is a warning and an empty set: a broken pack
    must never stop Microsoft 365 connections.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()] [string] $PackLock,
        # The folder config discovery starts from; the current folder by default.
        [Parameter()] [string] $Path,
        [Parameter()] [AllowNull()] [object] $RunConfig
    )

    if (-not $Path) { $Path = (Get-Location).Path }
    try {
        if (-not $RunConfig) { $RunConfig = Resolve-MtRunConfig -Path $Path -WarningAction SilentlyContinue }
        $set = @(Resolve-MtPackSet -RunConfig $RunConfig -LockPath (Resolve-MtPackLockPath -PackLock $PackLock -Path $Path).LockPath)
        $null = Register-MtPackService -PackSet $set
        $script:__MtPackSet = $set
        $set
    } catch {
        Write-Warning "Installed packs could not be read: $($_.Exception.Message)"
        $script:__MtPackSet = @()
        $null = Register-MtPackService -PackSet @()
        @()
    }
}

function Invoke-MtPackConnector {
    <#
    .SYNOPSIS
    Calls one function of a pack connector (Connect, Test, Disconnect, Describe or Renew) inside its pack (Maester Packs design, section 6.1).

    .DESCRIPTION
    The pack's module is loaded through the loader gate's result (Import-MtPackModule) and the function is
    called inside it, so it reaches its own helpers. -Setting is splatted, keeping only the parameters the
    function has. Returns what the function returns; throws with its error. A connector that has no such
    function (an optional one) returns $null.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Service,
        [Parameter(Mandatory)] [ValidateSet('Connect', 'Test', 'Disconnect', 'Describe', 'Renew')] [string] $Function,
        [Parameter()] [hashtable] $Setting = @{}
    )

    $entry = (Get-MtServiceRegistry).Services[$Service]
    if (-not $entry -or -not $entry.ContainsKey('Pack')) { throw "No installed pack provides the service $Service." }
    $c = $entry.Connector
    if (-not ($c.PSObject.Properties[$Function] -and $c.$Function)) { return $null }
    $module = Import-MtPackModule -Pack $entry.Pack -PackSet @($script:__MtPackSet)
    $name = [string]$c.$Function
    $previous = $script:__MtActivePackService
    $script:__MtActivePackService = $Service
    try {
        & $module {
            param($__name, $__setting)
            $command = Get-Command -Name $__name -CommandType Function -ErrorAction Stop
            $bound = @{}
            foreach ($k in $__setting.Keys) { if ($command.Parameters.ContainsKey($k)) { $bound[$k] = $__setting[$k] } }
            & $command @bound
        } $name $Setting
    } finally {
        $script:__MtActivePackService = $previous
    }
}

function Test-MtPackConnection {
    <#
    .SYNOPSIS
    Returns whether a pack connector's service is connected: its Test function, renewed first when its token is about to expire (section 6.5).
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param([Parameter(Mandatory)] [string] $Service)

    $state = if ($__MtSession.PackConnections) { $__MtSession.PackConnections[$Service] } else { $null }
    try {
        if ($state -and $state.Value -is [System.Collections.IDictionary] -and $state.Value.Contains('ExpiresOn') -and $state.Value['ExpiresOn']) {
            $expires = [datetime]$state.Value['ExpiresOn']
            if ($expires.ToUniversalTime() -lt [datetime]::UtcNow.AddMinutes(10)) { $null = Invoke-MtPackConnector -Service $Service -Function Renew }
        }
        [bool](Invoke-MtPackConnector -Service $Service -Function Test)
    } catch {
        Write-Verbose "The connector of $Service failed its test: $($_.Exception.Message)"
        $false
    }
}
