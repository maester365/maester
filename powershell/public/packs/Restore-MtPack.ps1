function Restore-MtPack {
    <#
    .SYNOPSIS
    Installs exactly the packs and modules that maester-packs.lock.json records, on a new computer or in a pipeline.

    .DESCRIPTION
    For each pack in the lock file whose files are not in the local pack store, the recorded commit is
    fetched and its digest must equal the digest in the lock file; a pack whose files differ is not
    restored. Each module in the lock file is saved at its exact version and must match its recorded
    digest. Nothing is asked: the lock file is the approval, made when the pack was installed. A module
    that was externally managed when it was approved is not saved; it must be installed on this computer
    at the same version and with the same files.

    Run it before Invoke-Maester in a pipeline that commits maester-config.json and maester-packs.lock.json.

    .PARAMETER Id
    Restore only these packs. By default every pack in the lock file.

    .PARAMETER PackLock
    The lock file to restore from. By default the one beside the Maester config found from the current
    folder, else the user's.

    .EXAMPLE
    Restore-MtPack

    Restores every pack of the lock file found from the current folder.

    .EXAMPLE
    Restore-MtPack -PackLock ./maester/maester-packs.lock.json; Invoke-Maester -Path ./maester

    Restores, then runs, in a pipeline.

    .LINK
    https://maester.dev/docs/commands/Restore-MtPack
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Id,

        [Parameter()]
        [string] $PackLock
    )

    Write-Verbose "Restore-MtPack: Id=$($Id -join ', ') PackLock=$PackLock"

    $where = Resolve-MtPackLockPath -PackLock $PackLock -Path (Get-Location).Path
    if (-not (Test-Path -LiteralPath $where.LockPath -PathType Leaf)) { throw "There is no pack lock file at '$($where.LockPath)'." }
    $lock = Read-MtPackLock -Path $where.LockPath
    $packs = @($lock.Packs | Where-Object { -not $Id -or $_.Id -in $Id })
    $failed = 0

    foreach ($entry in $packs) {
        $status = 'Present'
        $reason = $null
        if ($entry.Source -ne 'builtin') {
            $target = Get-MtPackStorePath -Digest $entry.Digest
            $present = (Test-Path -LiteralPath $target -PathType Container) -and (Get-MtPackDigest -Path $target).Digest -eq $entry.Digest
            if (-not $present -and $PSCmdlet.ShouldProcess("$($entry.Id) $($entry.Version)", 'Restore the pack')) {
                $candidate = $null
                try {
                    $candidate = Get-MtPackCandidate -Source $entry.Source -Commit $entry.Commit -IncludeRecent
                    if ($candidate.Digest -ne $entry.Digest) { throw "its files are not the approved files (digest $($candidate.Digest), the lock file has $($entry.Digest))." }
                    $null = Save-MtPackToStore -Path $candidate.Root -Digest $entry.Digest
                    $status = 'Restored'
                } catch {
                    $status = 'Failed'; $reason = $_.Exception.Message; $failed++
                    Write-Error "The pack $($entry.Id) $($entry.Version) was not restored: $reason"
                } finally {
                    if ($candidate -and $candidate.Staging) { Remove-Item -LiteralPath $candidate.Staging -Recurse -Force -ErrorAction SilentlyContinue }
                }
            }
        }
        [pscustomobject]@{ Kind = 'Pack'; Name = $entry.Id; Version = $entry.Version; Status = $status; Reason = $reason }
    }

    $modules = @($lock.Modules | Where-Object { -not $Id -or (@($_.RequiredBy) | Where-Object { $_ -in $Id }) })
    $store = (Get-MtPackHome).Modules
    foreach ($m in $modules) {
        $status = 'Present'
        $reason = $null
        $path = if ($m.Source -eq 'External') { Find-MtPackModuleFolder -Name $m.Name -Version $m.Version } else { Find-MtPackModuleFolder -Name $m.Name -Version $m.Version -Root $store }
        try {
            if (-not $path) {
                if ($m.Source -eq 'External') { throw "it was approved as your own install, and it is not installed here. Install $($m.Name) $($m.Version), or run Install-MtPack again." }
                if (-not $PSCmdlet.ShouldProcess("$($m.Name) $($m.Version)", 'Save the module')) { continue }
                Save-MtPackModuleFromGallery -Name $m.Name -Version $m.Version -Store $store -Repository 'PSGallery'
                $path = Find-MtPackModuleFolder -Name $m.Name -Version $m.Version -Root $store
                if (-not $path) { throw 'it could not be saved from the PowerShell Gallery.' }
                $status = 'Restored'
            }
            $digest = (Get-MtPackDigest -Path $path).Digest
            if ($digest -ne $m.Digest) { throw "its files are not the approved files (digest $digest, the lock file has $($m.Digest))." }
        } catch {
            $status = 'Failed'; $reason = $_.Exception.Message; $failed++
            Write-Error "The module $($m.Name) $($m.Version) was not restored: $reason"
        }
        [pscustomobject]@{ Kind = 'Module'; Name = $m.Name; Version = $m.Version; Status = $status; Reason = $reason }
    }
    if ($failed -gt 0) { Write-Warning "$failed item(s) were not restored; the packs that need them will not run." }
}
