function Resolve-MtConnectionStateService {
    <#
    .SYNOPSIS
    Works out which pack service Set-, Get- or Clear-MtConnectionState acts on, and refuses another pack's service.

    .DESCRIPTION
    In a pack's code, the calling pack is known from the module the call comes from (Get-MtCallingPack).
    The service is -Service, else the connector whose function is running, else the pack's only connector.
    A pack may act on its own services, and read (not -Write) those of the packs it requires. Outside a
    pack, -Service is required and must be a pack service.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter()] [string] $Service,
        [Parameter()] [AllowNull()] [System.Management.Automation.SessionState] $SessionState,
        # Set or Clear: only the pack's own services.
        [Parameter()] [switch] $Write
    )

    $registry = (Get-MtServiceRegistry).Services
    $packServices = @($registry.Keys | Where-Object { $registry[$_].ContainsKey('Pack') })
    $caller = Get-MtCallingPack -SessionState $SessionState
    if (-not $caller) {
        if (-not $Service) { throw 'Name the service with -Service: this command is called from outside a Maester Pack.' }
        $match = $packServices | Where-Object { $_ -eq $Service } | Select-Object -First 1
        if (-not $match) { throw "No installed pack provides the service $Service." }
        return [string]$match
    }

    $own = @($caller.Manifest.Connectors | ForEach-Object { [string]$_.Service })
    if (-not $Service) {
        if ($script:__MtActivePackService -and $script:__MtActivePackService -in $own) { return [string]$script:__MtActivePackService }
        if ($own.Count -eq 1) { return $own[0] }
        throw "The pack $($caller.Id) has $(if ($own.Count) { "$($own.Count) connectors" } else { 'no connector' }); name the service with -Service."
    }
    $match = $own | Where-Object { $_ -eq $Service } | Select-Object -First 1
    if ($match) { return [string]$match }
    if (-not $Write) {
        $required = @($caller.Manifest.RequiredPacks | ForEach-Object { [string]$_.Id })
        $providers = @($packServices | Where-Object { $_ -eq $Service -and $registry[$_].Pack.Id -in $required })
        if ($providers.Count -gt 0) { return [string]$providers[0] }
    }
    throw "The pack $($caller.Id) cannot $(if ($Write) { 'change' } else { 'read' }) the connection of $Service, which is not its own service$(if (-not $Write) { ' or one of a pack it requires' })."
}
