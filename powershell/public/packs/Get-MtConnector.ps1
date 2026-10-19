function Get-MtConnector {
    <#
    .SYNOPSIS
    Lists the services that installed Maester Packs connect to, and whether each is connected.

    .DESCRIPTION
    A pack connector adds a service to Maester (Maester Packs design, section 6): Connect-Maester -Service
    connects to it, and the pack's tests that declare it are skipped while it is not connected. Each row
    has Service, DisplayName, Pack, Version, OptIn, Connected and Account.

    .PARAMETER Service
    Only these services: names or '*' wildcards.

    .EXAMPLE
    Get-MtConnector

    Lists the pack services and which of them are connected.

    .LINK
    https://maester.dev/docs/commands/Get-MtConnector
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Service
    )

    $null = Initialize-MtPackSet
    $registry = (Get-MtServiceRegistry).Services
    foreach ($name in ($registry.Keys | Sort-Object)) {
        $entry = $registry[$name]
        if (-not $entry.ContainsKey('Pack')) { continue }
        if ($Service -and -not ($Service | Where-Object { $name -like $_ })) { continue }
        $state = if ($__MtSession.PackConnections) { $__MtSession.PackConnections[$name] } else { $null }
        [pscustomobject][ordered]@{
            Service     = $name
            DisplayName = ConvertTo-MtPackSafeText $entry.DisplayName
            Pack        = $entry.Pack.Id
            Version     = $entry.Pack.Version
            OptIn       = [bool]$entry.OptIn
            Connected   = Test-MtPackConnection -Service $name
            Account     = if ($state) { $state.Account } else { $null }
        }
    }
}
