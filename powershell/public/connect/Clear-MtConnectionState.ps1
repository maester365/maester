function Clear-MtConnectionState {
    <#
    .SYNOPSIS
    Forgets the connection of a Maester Pack connector.

    .DESCRIPTION
    A pack connector calls this from its Disconnect function (Maester Packs design, section 6.1).
    Disconnect-Maester also clears the state of every pack service it disconnects. Inside a pack it clears
    the pack's own service; outside a pack, -Service is required.

    .PARAMETER Service
    The connector's service name, such as CNT.GoogleWorkspace. Needed only when the pack has more than one
    connector, or outside a pack.

    .EXAMPLE
    Clear-MtConnectionState

    Inside a pack connector's Disconnect function: forgets its connection.

    .LINK
    https://maester.dev/docs/commands/Clear-MtConnectionState
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0)]
        [string] $Service
    )

    Write-Verbose "Clear-MtConnectionState: Service=$Service"

    $resolved = Resolve-MtConnectionStateService -Service $Service -SessionState $PSCmdlet.SessionState -Write
    if ($__MtSession.PackConnections -and $__MtSession.PackConnections.ContainsKey($resolved) -and $PSCmdlet.ShouldProcess($resolved, 'Forget the connection state')) {
        $__MtSession.PackConnections.Remove($resolved)
    }
}
