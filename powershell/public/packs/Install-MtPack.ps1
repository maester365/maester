function Install-MtPack {
    <#
    .SYNOPSIS
    Installs a Maester Pack: tests, helpers and connectors that someone else publishes, checked and pinned before anything runs.

    .DESCRIPTION
    A pack comes from a GitHub repository (owner/repo, owner/repo/folder, owner/repo@ref or a github.com
    URL), a local folder, or, by its ID, from the packs that ship with Maester. Before anything is saved:

    - the pack is fetched and read without running any of its code: its manifest, every file and what its
      scripts call;
    - a GitHub release must be at least the cooldown old (72 hours by default; PackPolicy.CooldownHours).
      Only an immutable release counts its publish date; otherwise the clock starts when this computer
      first sees the commit, so a moved tag starts the clock again. -IncludeRecent installs a newer one;
    - the pack policy and the signed blocklist are checked;
    - the PowerShell Gallery modules it declares are saved at their exact versions into the pack store,
      and the digest of each module folder is recorded;
    - you are shown what the pack can reach, its risk and anything the scan found, and asked to approve.

    The approved files are copied into the read-only pack store under their digest, and the pack is
    written to maester-packs.lock.json (commit, digest, test IDs, risk and modules) and to the Packs list
    of maester-config.json. Commit both files: Restore-MtPack installs the same files on another computer
    or in a pipeline, and Invoke-Maester runs a pack only while its files still match the lock file.

    A pack that ships with Maester (by ID, such as maester.zero-trust-assessment) needs no approval. Installing it only
    saves and pins the modules it declares.

    .PARAMETER Source
    Where the pack comes from: owner/repo, owner/repo/folder, owner/repo@ref, a github.com URL, a local
    folder, or the ID of a pack that ships with Maester.

    .PARAMETER Version
    The release to install, such as 1.2.0. By default the newest release that has met the cooldown.

    .PARAMETER Scope
    Project writes to the maester-config.json found from the current folder (created there if there is
    none); User writes to ~/.maester. By default the project when it has a config, else the user.

    .PARAMETER PackLock
    The lock file to write instead of the one Scope chooses.

    .PARAMETER AcceptRisk
    The highest risk a pack may have to be installed without asking: Low, Medium or High. Needed with
    -NonInteractive for a pack above Low.

    .PARAMETER IncludeRecent
    Install a release or commit that is newer than the cooldown.

    .PARAMETER NonInteractive
    Never ask. Used automatically when the input is redirected; then -AcceptRisk must cover the pack's risk.

    .PARAMETER Force
    Answer yes to the approval question. A pack of High risk, or one newer than the cooldown, still needs
    its code typed unless -AcceptRisk and -IncludeRecent cover it.

    .PARAMETER PassThru
    Return the lock file entry of the pack. Without it, Install-MtPack writes what was installed and how to
    run it, and returns nothing.

    .EXAMPLE
    Install-MtPack contoso/maester-google-workspace

    Installs the newest release that has met the cooldown, after showing what it can reach.

    .EXAMPLE
    Install-MtPack contoso/maester-google-workspace -Version 1.2.0 -AcceptRisk Medium -NonInteractive

    Installs a given release in a pipeline.

    .EXAMPLE
    Install-MtPack maester.zero-trust-assessment

    Saves and pins the modules of the Zero Trust Assessment pack, which ships with Maester.

    .EXAMPLE
    Install-MtPack maester365/maester-pack-demo
    Invoke-Maester -Pack DEMO -SkipBuiltIn

    Installs the demo pack, then runs only its tests, by the pack's code.

    .LINK
    https://maester.dev/docs/commands/Install-MtPack
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory, Position = 0)]
        [string] $Source,

        [Parameter()]
        [string] $Version,

        [Parameter()]
        [ValidateSet('Project', 'User')]
        [string] $Scope,

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
        [switch] $Force,

        [Parameter()]
        [switch] $PassThru
    )

    $where = Resolve-MtPackLockPath -PackLock $PackLock -Scope $Scope -Path (Get-Location).Path
    $lock = Read-MtPackLock -Path $where.LockPath
    $runConfig = Get-MtPackRunConfig -ConfigPath $where.ConfigPath
    $policy = Get-MtPackPolicy -RunConfig $runConfig
    $quiet = $NonInteractive -or (Test-MtPackNonInteractive)

    $before = @($lock.Packs | ForEach-Object { $_.Id })
    $entry = Invoke-MtPackInstall -Source $Source -Version $Version -Lock $lock -Policy $policy -AcceptRisk $AcceptRisk -IncludeRecent:$IncludeRecent -Force:$Force -NonInteractive:$quiet -Previous ($lock.Packs | Where-Object { $_.Id -eq $Source -or $_.Source -eq $Source } | Select-Object -First 1)
    if (-not $entry) { return }

    Write-MtPackLock -Path $where.LockPath -Lock $lock
    if ($where.ConfigPath) {
        foreach ($e in ($lock.Packs | Where-Object { $_.Source -ne 'builtin' -and ($_.Id -eq $entry.Id -or $_.Id -notin $before) })) {
            Update-MtPackConfig -Path $where.ConfigPath -Id $e.Id -Entry ([ordered]@{ Id = $e.Id; Source = $e.Source; Version = $e.Version })
        }
    }
    Write-Verbose "The pack $($entry.Id) $($entry.Version) is in $($where.LockPath)."
    Show-MtPackInstalled -Entry $entry -LockPath $where.LockPath -ConfigPath $where.ConfigPath
    if ($PassThru) { $entry }
}
