function Uninstall-MtPack {
    <#
    .SYNOPSIS
    Removes a Maester Pack from maester-packs.lock.json and the Maester config.

    .DESCRIPTION
    The pack and the modules only it needed are removed from the lock file, and its entry from the Packs
    list of maester-config.json, so Invoke-Maester no longer runs it. A pack that another installed pack
    requires is not removed. The files stay in the local pack store, which other projects may share.

    A pack that ships with Maester cannot be uninstalled; turn it off in the config instead, with
    Packs: [{ "Id": "maester.zero-trust", "Enabled": false }].

    .PARAMETER Id
    The packs to remove.

    .PARAMETER PackLock
    The lock file to change. By default the one beside the Maester config found from the current folder,
    else the user's.

    .EXAMPLE
    Uninstall-MtPack contoso.google-workspace

    Removes the pack from the project.

    .LINK
    https://maester.dev/docs/commands/Uninstall-MtPack
    #>
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string[]] $Id,

        [Parameter()]
        [string] $PackLock
    )

    Write-Verbose "Uninstall-MtPack: Id=$($Id -join ', ')"

    $where = Resolve-MtPackLockPath -PackLock $PackLock -Path (Get-Location).Path
    $lock = Read-MtPackLock -Path $where.LockPath
    $removed = [System.Collections.Generic.List[string]]::new()
    foreach ($packId in $Id) {
        if (Get-MtBuiltInPack | Where-Object Id -EQ $packId) {
            Write-Error "The pack $packId ships with Maester and cannot be uninstalled. To turn it off, add { `"Id`": `"$packId`", `"Enabled`": false } to Packs in maester-config.json."
            continue
        }
        $entry = $lock.Packs | Where-Object Id -EQ $packId | Select-Object -First 1
        if (-not $entry) { Write-Error "The pack $packId is not installed in '$($where.LockPath)'."; continue }
        $dependents = @($lock.Packs | Where-Object { $_.Id -notin $Id -and @($_.Requires) -contains $packId } | ForEach-Object Id)
        if ($dependents.Count -gt 0) { Write-Error "The pack $packId is required by $($dependents -join ', '); uninstall those first."; continue }
        if (-not $PSCmdlet.ShouldProcess($packId, 'Uninstall the pack')) { continue }
        $lock.Packs = @($lock.Packs | Where-Object Id -NE $packId)
        $modules = foreach ($m in $lock.Modules) {
            $m.RequiredBy = @(@($m.RequiredBy) | Where-Object { $_ -ne $packId })
            if ($m.RequiredBy.Count -gt 0) { $m }
        }
        $lock.Modules = @($modules)
        $removed.Add($packId)
    }
    if ($removed.Count -eq 0) { return }
    Write-MtPackLock -Path $where.LockPath -Lock $lock
    if ($where.ConfigPath -and (Test-Path -LiteralPath $where.ConfigPath -PathType Leaf)) {
        foreach ($packId in $removed) { Update-MtPackConfig -Path $where.ConfigPath -Id $packId -Remove }
    }
}
