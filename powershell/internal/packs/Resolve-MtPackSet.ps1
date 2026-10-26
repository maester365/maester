function Resolve-MtPackSet {
    <#
    .SYNOPSIS
    The loader gate: decides, before any pack code runs, which packs may load (Maester Packs design, sections 4.4, 5.5 and 9.8).

    .DESCRIPTION
    Every path that loads pack code goes through here: Invoke-Maester, Invoke-MtTest, Connect-Maester,
    Disconnect-Maester, Test-MtConnection and Get-MtTenantContext. For each pack it checks, in order:

    1. Config: Packs[].Enabled = false turns a pack off (Disabled). A pack that ships with Maester follows
       its EnabledByDefault unless the config names it. With -Select (Invoke-Maester -Pack), only the packs it
       names run, whatever the config and EnabledByDefault say; the others are Disabled (NotSelected).
       With -NamedOnly (a run), an installed pack runs only when -Select names it or the config turns it on
       with Packs[].Enabled = true; otherwise it is Disabled (NotSelected). Installing a pack does not run it.
    2. The store: an installed pack must be in the local store (else Unavailable, PackUnavailable) and its
       files must match the digest in the lock file (else Unavailable, with a warning that the files changed).
    3. Its manifest, read again from the checked files, and RequiresMaester.
    4. The pack policy (else NotAllowed, PackNotAllowed) and the signed blocklist (else Blocked, PackBlocked).
    5. Its Gallery modules: each must be where the lock says, with the digest the lock records (else
       Failed, PackLoadFailed). A built-in pack whose modules were never saved is Unavailable.
    6. The packs it requires must be Ready too.

    Returns one row per pack: Id, Version, BuiltIn, Root, Manifest, Entry (the lock entry), Modules (the
    lock's module rows for it, with Path), Status (Ready, Disabled, Unavailable, NotAllowed, Blocked or
    Failed), ReasonCode, Reason, TestIds and Selected (named by -Select). Warnings are written once.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject], [System.Array])]
    param(
        [Parameter()] [AllowNull()] [object] $RunConfig,
        # The lock file; by default the one Resolve-MtPackLockPath finds from the current folder.
        [Parameter()] [string] $LockPath,
        [Parameter()] [AllowNull()] [pscustomobject] $Policy,
        # Pack IDs or codes, with '*' wildcards: run only these packs (Invoke-Maester -Pack).
        [Parameter()] [AllowEmptyCollection()] [string[]] $Select = @(),
        # Run an installed pack only when -Select names it or the config sets Enabled to true.
        [Parameter()] [switch] $NamedOnly
    )

    if (-not $LockPath) { $LockPath = (Resolve-MtPackLockPath).LockPath }
    if (-not $Policy) { $Policy = Get-MtPackPolicy -RunConfig $RunConfig }
    $lock = Read-MtPackLock -Path $LockPath
    $configPacks = @($(if ($RunConfig -and $RunConfig.PSObject.Properties['Packs']) { $RunConfig.Packs }) | Where-Object { $_ })
    $configFor = { param($id) $configPacks | Where-Object { $_.PSObject.Properties['Id'] -and $_.Id -eq $id } | Select-Object -First 1 }
    $enabledIn = { param($row) if ($row -and $row.PSObject.Properties['Enabled'] -and $null -ne $row.Enabled) { [bool]$row.Enabled } else { $null } }
    # A name in -Select matches a pack's ID or its code. An installed pack's code is known before its manifest
    # is read from the test IDs the lock file records, MP.<code>.<n>.
    $Select = @($Select | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $matched = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $selects = {
        param($id, $code, $testIds)
        $hit = $false
        foreach ($name in $Select) {
            $byCode = if ($code) { $code -like $name } else { [bool](@($testIds) | Where-Object { $_ -like "MP.$name.*" -or $_ -like "MP.$name" }) }
            if ($id -like $name -or $byCode) { $null = $matched.Add($name); $hit = $true }
        }
        $hit
    }
    $notSelected = { param($row) & $stop $row 'Disabled' 'NotSelected' "The pack $($row.Id) was not named in -Pack." }

    # Fetched once, when the first installed pack needs it; its warning is written once.
    $state = @{ Blocklist = $null }
    $getBlocklist = {
        if ($null -eq $state.Blocklist) {
            $state.Blocklist = Get-MtPackBlocklist -RequireFresh:$Policy.RequireFreshBlocklist
            if ($state.Blocklist.Warning) { Write-Warning $state.Blocklist.Warning }
        }
        $state.Blocklist
    }

    $rows = [ordered]@{}
    $new = {
        param($id, $builtIn, $entry)
        [pscustomobject][ordered]@{
            Id = $id; Version = $null; BuiltIn = $builtIn; Root = $null; Manifest = $null; Entry = $entry; Modules = @()
            Status = 'Ready'; ReasonCode = $null; Reason = $null; TestIds = @($(if ($entry) { $entry.Tests })); Selected = $false
        }
    }
    $stop = { param($row, $status, $code, $reason) $row.Status = $status; $row.ReasonCode = $code; $row.Reason = $reason }

    foreach ($pack in (Get-MtBuiltInPack)) {
        $row = & $new $pack.Id $true ($lock.Packs | Where-Object { $_.Id -eq $pack.Id } | Select-Object -First 1)
        $row.Root = $pack.Root
        $row.Manifest = $pack.Manifest
        $row.Version = if ($pack.Manifest) { [string]$pack.Manifest.Version } else { $null }
        $enabled = & $enabledIn (& $configFor $pack.Id)
        if ($null -eq $enabled) { $enabled = -not $pack.Manifest -or $pack.Manifest.EnabledByDefault }
        if ($Select.Count -gt 0) {
            $row.Selected = & $selects $pack.Id $(if ($pack.Manifest) { [string]$pack.Manifest.Code }) @()
            $enabled = $row.Selected
        }
        if (-not $enabled -and $Select.Count -gt 0) { & $notSelected $row }
        elseif (-not $enabled) { & $stop $row 'Disabled' 'DisabledByConfig' "The pack $($pack.Id) is turned off$(if ($pack.Manifest -and -not $pack.Manifest.EnabledByDefault) { ' by default. Set Packs: [{ "Id": "' + $pack.Id + '", "Enabled": true }] in the Maester config to run it' })." }
        elseif ($pack.Errors.Count -gt 0) { & $stop $row 'Failed' 'PackLoadFailed' "The pack $($pack.Id) that ships with Maester has a problem: $($pack.Errors[0].Message)" }
        $rows[$pack.Id] = $row
    }

    foreach ($entry in $lock.Packs) {
        if ($entry.Source -eq 'builtin' -or $rows.Contains([string]$entry.Id)) { continue }
        $row = & $new ([string]$entry.Id) $false $entry
        $row.Version = [string]$entry.Version
        $rows[$row.Id] = $row
        $enabled = & $enabledIn (& $configFor $entry.Id)
        if ($Select.Count -gt 0) {
            $row.Selected = & $selects $row.Id $null $row.TestIds
            if (-not $row.Selected) { & $notSelected $row; continue }
        } elseif ($enabled -eq $false) { & $stop $row 'Disabled' 'DisabledByConfig' "The pack $($entry.Id) is turned off in the Maester config."; continue }
        elseif ($NamedOnly -and $enabled -ne $true) {
            $code = if ($entry.PSObject.Properties['Code'] -and $entry.Code) { [string]$entry.Code } else { [string]$entry.Id }
            & $stop $row 'Disabled' 'NotSelected' "The pack $($entry.Id) is installed but was not named. Run it with Invoke-Maester -Pack $code, or every installed pack with -AllPacks."
            continue
        }
        $root = if ($entry.Digest) { Get-MtPackStorePath -Digest $entry.Digest } else { $null }
        if (-not $root -or -not (Test-Path -LiteralPath $root -PathType Container)) {
            & $stop $row 'Unavailable' 'PackUnavailable' "The pack $($entry.Id) $($entry.Version) is in the lock file but not on this computer. Run Restore-MtPack."
            continue
        }
        $actual = (Get-MtPackDigest -Path $root).Digest
        if ($actual -ne $entry.Digest) {
            Write-Warning "The files of the pack $($entry.Id) in '$root' do not match the lock file, so it was not run. Run Restore-MtPack to restore the approved files."
            & $stop $row 'Unavailable' 'PackUnavailable' "The files of the pack $($entry.Id) changed after it was approved (digest $actual, the lock file has $($entry.Digest))."
            continue
        }
        $row.Root = $root
        $read = Read-MtPackManifest -Path $root -Official:($entry.Publisher -eq 'maester365')
        $row.Manifest = $read.Manifest
        if ($read.Errors.Count -gt 0) { & $stop $row 'Failed' 'PackLoadFailed' "The pack $($entry.Id) has a problem: $($read.Errors[0].Message)"; continue }
        $problem = Test-MtPackPolicy -Policy $Policy -PackId $entry.Id -Publisher $entry.Publisher -Source $entry.Source -Digest $entry.Digest -Risk $(if ($entry.AcceptedRisk) { $entry.AcceptedRisk } else { 'High' })
        if (-not $problem -and @($read.Manifest.Uses.UserModules).Count -gt 0 -and -not $Policy.AllowExternalEnvironments) {
            $problem = "The pack $($entry.Id) runs modules you install yourself, and PackPolicy.AllowExternalEnvironments is false."
        }
        if ($problem) { & $stop $row 'NotAllowed' 'PackNotAllowed' $problem; continue }
        $list = & $getBlocklist
        $block = Find-MtPackBlock -Entry $list.Entries -PackId $entry.Id -Version $entry.Version -Digest $entry.Digest -RepositoryId ([long]$entry.RepositoryId) -OwnerId ([long]$entry.OwnerId)
        if ($block -and $block.Severity -ne 'Warn') {
            Write-Warning "The pack $($entry.Id) $($entry.Version) is blocked and was not run: $(ConvertTo-MtPackSafeText $block.Advisory -MaxLength 300)"
            & $stop $row 'Blocked' 'PackBlocked' "Blocked: $(ConvertTo-MtPackSafeText $block.Advisory -MaxLength 300)"
            continue
        }
        if ($block) { Write-Warning "The pack $($entry.Id) has an advisory: $(ConvertTo-MtPackSafeText $block.Advisory -MaxLength 300)" }
    }

    foreach ($name in ($Select | Where-Object { -not $matched.Contains($_) })) {
        Write-Warning "-Pack '$name' matches no pack that ships with Maester or is in the lock file. Get-MtPack lists them."
    }

    foreach ($configRow in $configPacks) {
        $id = if ($configRow.PSObject.Properties['Id']) { [string]$configRow.Id } else { $null }
        if ($id -and -not $rows.Contains($id) -and (& $enabledIn $configRow) -ne $false) {
            Write-Warning "The Maester config lists the pack $id, but it is not installed here. Run Restore-MtPack, or Install-MtPack $(if ($configRow.PSObject.Properties['Source']) { $configRow.Source } else { $id })."
        }
    }

    # Two packs whose codes overlap (Test-MtPackCodeOverlap) would write rows with the same IDs. Install-MtPack
    # refuses the second one, so this only happens with a lock file edited by hand or restored from elsewhere:
    # the packs that ship with Maester win, then the one earlier in the lock file.
    $claimed = [System.Collections.Generic.List[object]]::new()
    foreach ($row in ($rows.Values | Where-Object { $_.Status -eq 'Ready' -and $_.Manifest -and $_.Manifest.Code })) {
        $owner = $claimed | Where-Object { Test-MtPackCodeOverlap -Code ([string]$row.Manifest.Code) -Other ([string]$_.Manifest.Code) } | Select-Object -First 1
        if ($owner) { & $stop $row 'Failed' 'PackLoadFailed' "The pack $($row.Id) has the code $($row.Manifest.Code), which overlaps the code $($owner.Manifest.Code) of $($owner.Id), so it was not run. Uninstall one of them."; continue }
        $claimed.Add($row)
    }

    # RequiresMaester and modules, for every pack still in the running.
    $moduleVersion = $ExecutionContext.SessionState.Module.Version
    foreach ($row in ($rows.Values | Where-Object Status -EQ 'Ready')) {
        $m = $row.Manifest
        # A pack that ships with Maester always matches the module it ships in, whose source says 3.0.0 until a release sets it.
        if (-not $row.BuiltIn -and $m.PSObject.Properties['RequiresMaester'] -and $m.RequiresMaester -and -not (Test-MtVersionRange -Range ([string]$m.RequiresMaester) -Version $moduleVersion)) {
            & $stop $row 'Failed' 'RequiresNewerMaester' "The pack $($row.Id) requires Maester $($m.RequiresMaester); this is $moduleVersion."
            continue
        }
        $declared = @($m.Uses.Modules)
        if ($declared.Count -eq 0) { continue }
        $locked = @($lock.Modules | Where-Object { @($_.RequiredBy) -contains $row.Id })
        $missing = @($declared | Where-Object { $d = $_; -not ($locked | Where-Object { $_.Name -eq $d.Name -and $_.Version -eq [string]$d.Version }) })
        if ($missing.Count -gt 0) {
            $how = if ($row.BuiltIn) { "Run Install-MtPack $($row.Id) to save them." } else { 'Run Install-MtPack again to review and save them.' }
            & $stop $row 'Unavailable' 'PackUnavailable' "The pack $($row.Id) needs the modules $(@($missing | ForEach-Object { "$($_.Name) $($_.Version)" }) -join ', '), which are not pinned in the lock file. $how"
            continue
        }
        $checked = foreach ($lm in $locked) {
            $path = if ($lm.Source -eq 'External') {
                if ($Policy.AllowExternalEnvironments) { Find-MtPackModuleFolder -Name $lm.Name -Version $lm.Version } else { $null }
            } else { Find-MtPackModuleFolder -Name $lm.Name -Version $lm.Version -Root (Get-MtPackHome).Modules }
            if (-not $path) {
                $why = if ($lm.Source -eq 'External' -and -not $Policy.AllowExternalEnvironments) { 'the pack policy does not allow externally managed modules' } else { 'it is not on this computer; run Restore-MtPack' }
                & $stop $row 'Unavailable' 'PackUnavailable' "The module $($lm.Name) $($lm.Version) that the pack $($row.Id) needs cannot be used: $why."
                break
            }
            $digest = (Get-MtPackDigest -Path $path).Digest
            if ($digest -ne $lm.Digest) {
                Write-Warning "The module $($lm.Name) $($lm.Version) in '$path' changed after the pack $($row.Id) was approved with it, so the pack was not run."
                & $stop $row 'Failed' 'PackLoadFailed' "The module $($lm.Name) $($lm.Version) changed after it was approved (digest $digest, the lock file has $($lm.Digest)). Run Install-MtPack again to review it."
                break
            }
            [pscustomobject]@{ Name = $lm.Name; Version = $lm.Version; Source = $lm.Source; Path = $path }
        }
        if ($row.Status -eq 'Ready') { $row.Modules = @($checked) }
    }

    # Required packs must be Ready.
    $changed = $true
    while ($changed) {
        $changed = $false
        foreach ($row in ($rows.Values | Where-Object Status -EQ 'Ready')) {
            foreach ($r in @($row.Manifest.RequiredPacks)) {
                $required = $rows[[string]$r.Id]
                if (-not $required -or $required.Status -ne 'Ready') {
                    & $stop $row 'Failed' 'PackLoadFailed' "The pack $($row.Id) requires $($r.Id), which $(if ($required) { "could not be loaded: $($required.Reason)" } else { 'is not installed' })"
                    $changed = $true
                    break
                }
            }
        }
    }
    @($rows.Values)
}
