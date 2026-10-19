function Set-MtConnectionState {
    <#
    .SYNOPSIS
    Keeps the connection of a Maester Pack connector for the session, so its tests and Connect-Maester can find it.

    .DESCRIPTION
    A pack connector calls this from its Connect function (Maester Packs design, section 6.1). The state is
    kept by Maester, per service, in the PowerShell session only: it is never written to disk or to the
    report. The tests of the pack read it back with Get-MtConnectionState, and Disconnect-Maester clears it.

    The service is the connector's own: the one whose Connect function is running, or the only connector
    of the calling pack. A pack can set the state of its own services only; called from outside a pack,
    -Service is required.

    Put an access token's expiry in the value as ExpiresOn (a date) to have Maester call the connector's
    Renew function shortly before it expires.

    .PARAMETER Value
    What the pack needs to reach the service: a token, a client object or settings. Kept as it is.

    .PARAMETER Account
    The account or identity that is connected, shown by Get-MtTenantContext and in the report header.

    .PARAMETER Tenant
    The tenant, organisation or workspace that is connected, shown with the account.

    .PARAMETER Service
    The connector's service name, such as CNT.GoogleWorkspace. Needed only outside the connector's own
    Connect function when the pack has more than one connector.

    .EXAMPLE
    Set-MtConnectionState -Value @{ Token = $token; ExpiresOn = $expiresOn } -Account $user -Tenant $domain

    Inside a pack connector's Connect function: keeps the token for the pack's tests.

    .LINK
    https://maester.dev/docs/commands/Set-MtConnectionState
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [AllowNull()]
        [object] $Value,

        [Parameter()]
        [string] $Account,

        [Parameter()]
        [string] $Tenant,

        [Parameter()]
        [string] $Service
    )

    $resolved = Resolve-MtConnectionStateService -Service $Service -SessionState $PSCmdlet.SessionState -Write
    if (-not $PSCmdlet.ShouldProcess($resolved, 'Keep the connection state')) { return }
    if (-not $__MtSession.PackConnections) { $__MtSession.PackConnections = @{} }
    $__MtSession.PackConnections[$resolved] = [pscustomobject]@{
        Service     = $resolved
        Value       = $Value
        Account     = $Account
        Tenant      = $Tenant
        ConnectedAt = [datetime]::UtcNow
    }
}
