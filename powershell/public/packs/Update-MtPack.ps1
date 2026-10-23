function Update-MtPack {
    <#
    .SYNOPSIS
    Updates installed Maester Packs to their newest release that has met the cooldown, showing what changed.

    .DESCRIPTION
    Each pack is installed again from its source with the same checks as Install-MtPack: the cooldown, the
    pack policy, the blocklist and the scan. The approval shows what changed since the version you
    approved: new services, scopes, network hosts, modules and a higher risk. A pack whose newest release
    has the files you approved is left as it is, without asking again, and reported as UpToDate.

    .PARAMETER Id
    The packs to update. By default every pack installed from GitHub.

    .PARAMETER Version
    The release to update to. Only with one -Id.

    .PARAMETER PackLock
    The lock file to update. By default the one beside the Maester config found from the current folder,
    else the user's.

    .PARAMETER AcceptRisk
    The highest risk a pack may have to be updated without asking: Low, Medium or High.

    .PARAMETER IncludeRecent
    Update to a release that is newer than the cooldown.

    .PARAMETER NonInteractive
    Never ask. Used automatically when the input is redirected.

    .PARAMETER Force
    Answer yes to the approval question.

    .EXAMPLE
    Update-MtPack

    Updates every pack installed from GitHub.

    .EXAMPLE
    Update-MtPack contoso.google-workspace -Version 1.3.0

    Updates one pack to a given release.

    .LINK
    https://maester.dev/docs/commands/Update-MtPack
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Position = 0)]
        [string[]] $Id,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [string] $PackLock,

        [Parameter()]
        [ValidateSet('Low', 'Medium', 'High')]
        [string] $AcceptRisk = 'Low',

        [Parameter()]
        [switch] $IncludeRecent,

        [Parameter()]
        [switch] $NonInteractive,

        [Parameter()]
        [switch] $Force
    )

    Write-Verbose "Update-MtPack: Id=$($Id -join ', ') Version=$Version"

    if ($Version -and @($Id).Count -ne 1) { throw '-Version needs exactly one -Id.' }
    $where = Resolve-MtPackLockPath -PackLock $PackLock -Path (Get-Location).Path
    $lock = Read-MtPackLock -Path $where.LockPath
    $policy = Get-MtPackPolicy -RunConfig (Get-MtPackRunConfig -ConfigPath $where.ConfigPath)
    $quiet = $NonInteractive -or (Test-MtPackNonInteractive)
    foreach ($missing in @($Id | Where-Object { $_ } | Where-Object { $i = $_; -not ($lock.Packs | Where-Object Id -EQ $i) })) { Write-Error "The pack $missing is not installed." }
    $targets = @($lock.Packs | Where-Object { $_.Source -ne 'builtin' -and (-not $Id -or $_.Id -in $Id) })

    $changed = $false
    foreach ($previous in $targets) {
        # The source without the ref it was installed at, so the newest release is found.
        $source = ($previous.Source -replace '@[^/@]+$', '')
        if (-not $PSCmdlet.ShouldProcess($previous.Id, 'Update the pack')) { continue }
        try {
            $entry = Invoke-MtPackInstall -Source $source -Version $Version -Lock $lock -Policy $policy -AcceptRisk $AcceptRisk -IncludeRecent:$IncludeRecent -Force:$Force -NonInteractive:$quiet -Previous $previous -SkipUnchanged -Confirm:$false
        } catch {
            Write-Error "The pack $($previous.Id) was not updated: $($_.Exception.Message)"
            continue
        }
        if (-not $entry) { continue }
        $state = if ($entry.Digest -eq $previous.Digest) { 'UpToDate' } else { 'Updated' }
        if ($state -eq 'Updated') { $changed = $true }
        [pscustomobject]@{ Id = $entry.Id; PreviousVersion = $previous.Version; Version = $entry.Version; Status = $state }
    }
    if ($changed) {
        Write-MtPackLock -Path $where.LockPath -Lock $lock
        if ($where.ConfigPath) {
            foreach ($e in ($lock.Packs | Where-Object { $_.Source -ne 'builtin' -and $_.Id -in $targets.Id })) {
                Update-MtPackConfig -Path $where.ConfigPath -Id $e.Id -Entry ([ordered]@{ Id = $e.Id; Source = $e.Source; Version = $e.Version })
            }
        }
    }
}
