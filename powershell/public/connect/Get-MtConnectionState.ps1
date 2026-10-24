function Get-MtConnectionState {
    <#
    .SYNOPSIS
    Returns what a Maester Pack connector kept with Set-MtConnectionState, or nothing when it is not connected.

    .DESCRIPTION
    A pack's tests and helpers call this to reach the service their connector connected to (Maester Packs
    design, section 6.1). Inside a pack, it returns the state of the pack's own connector, or of a pack it
    requires; one pack cannot read another pack's connection. Called from outside a pack, -Service is
    required.

    By default the value the connector kept is returned. -Detailed returns Service, Value, Account, Tenant
    and ConnectedAt.

    .PARAMETER Service
    The connector's service name, such as CNT.GoogleWorkspace. Needed only when the pack has more than one
    connector, or outside a pack.

    .PARAMETER Detailed
    Return the whole record: Service, Value, Account, Tenant and ConnectedAt.

    .EXAMPLE
    $token = (Get-MtConnectionState).Token

    Inside a pack test: the token the pack's connector kept.

    .EXAMPLE
    Get-MtConnectionState -Service CNT.GoogleWorkspace -Detailed

    At the console: who is connected to the service of an installed pack.

    .LINK
    https://maester.dev/docs/commands/Get-MtConnectionState
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        [Parameter(Position = 0)]
        [string] $Service,

        [Parameter()]
        [switch] $Detailed
    )

    Write-Verbose "Get-MtConnectionState: Service=$Service"

    $resolved = Resolve-MtConnectionStateService -Service $Service -SessionState $PSCmdlet.SessionState
    if (-not $__MtSession.PackConnections -or -not $__MtSession.PackConnections.ContainsKey($resolved)) { return }
    $state = $__MtSession.PackConnections[$resolved]
    if ($Detailed) { $state } else { $state.Value }
}
