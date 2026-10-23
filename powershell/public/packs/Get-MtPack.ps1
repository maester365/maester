function Get-MtPack {
    <#
    .SYNOPSIS
    Lists the Maester Packs this folder runs: those that ship with Maester and those in maester-packs.lock.json, with whether each can run.

    .DESCRIPTION
    Each pack goes through the same checks Invoke-Maester applies before it loads a pack, and nothing of
    the pack is run: the config, the store and its digest, the pack policy, the blocklist and the digests
    of its modules. Status is Ready, Disabled, Unavailable, NotAllowed, Blocked or Failed, and Reason says
    why a pack will not run.

    .PARAMETER Id
    Only these packs: IDs or '*' wildcards.

    .PARAMETER PackLock
    The lock file to read. By default the one beside the Maester config found from the current folder,
    else the user's.

    .EXAMPLE
    Get-MtPack | Format-Table Id, Version, Status, Reason

    Shows which packs the next Invoke-Maester in this folder runs.

    .LINK
    https://maester.dev/docs/commands/Get-MtPack
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Id,

        [Parameter()]
        [string] $PackLock
    )

    Write-Verbose "Get-MtPack: Id=$($Id -join ', ') PackLock=$PackLock"

    foreach ($pack in (Initialize-MtPackSet -PackLock $PackLock)) {
        if ($Id -and -not ($Id | Where-Object { $pack.Id -like $_ })) { continue }
        $m = $pack.Manifest
        [pscustomobject][ordered]@{
            Id          = $pack.Id
            Name        = if ($m) { ConvertTo-MtPackSafeText ([string]$m.Name) } else { $null }
            Version     = $pack.Version
            Publisher   = if ($m) { [string]$m.Publisher } elseif ($pack.Entry) { $pack.Entry.Publisher } else { $null }
            BuiltIn     = [bool]$pack.BuiltIn
            Status      = $pack.Status
            Reason      = $pack.Reason
            Risk        = if ($pack.Entry) { $pack.Entry.AcceptedRisk } else { $null }
            Source      = if ($pack.Entry) { $pack.Entry.Source } elseif ($pack.BuiltIn) { 'builtin' } else { $null }
            Commit      = if ($pack.Entry) { $pack.Entry.Commit } else { $null }
            Services    = [string[]]@($(if ($m) { $m.Connectors | ForEach-Object { [string]$_.Service } }))
            Tests       = if ($pack.Root -and $m) { @(Get-MtPackTestInventory -PackSet @($pack)).Count } else { @($pack.TestIds).Count }
            Modules     = [string[]]@($pack.Modules | ForEach-Object { "$($_.Name) $($_.Version)" })
            Path        = $pack.Root
        }
    }
}
