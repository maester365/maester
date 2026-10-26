function Resolve-MtPackLockPath {
    <#
    .SYNOPSIS
    Works out which maester-config.json and maester-packs.lock.json a pack command uses (Maester Packs design, section 5.2).

    .DESCRIPTION
    In order: -PackLock; the MAESTER_PACK_LOCK environment variable; the lock file next to the
    maester-config.json that config discovery finds from -Path (the current folder by default); and only
    when there is no project config at all, the user scope: ~/.maester/maester-config.json and its lock file.

    -Scope Project uses the project config even when there is none yet: it is created in -Path. -Scope User
    always uses the user scope.

    Returns Scope (Project, User or Explicit), ConfigPath and LockPath. ConfigPath is $null for an explicit
    lock file that has no maester-config.json beside it.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # A lock file given by the caller.
        [Parameter()]
        [string] $PackLock,

        # The folder config discovery starts from.
        [Parameter()]
        [string] $Path,

        # Where to install: the project or the user scope. Without it, the project when it has a config.
        [Parameter()]
        # An empty value is the default, so commands can pass their own -Scope through.
        [ValidateSet('Project', 'User', '')]
        [string] $Scope
    )

    $lockName = 'maester-packs.lock.json'
    $explicit = if ($PackLock) { $PackLock } elseif ($env:MAESTER_PACK_LOCK) { $env:MAESTER_PACK_LOCK } else { $null }
    if ($explicit -and $Scope -ne 'User') {
        $full = [System.IO.Path]::GetFullPath($explicit)
        $config = Join-Path (Split-Path -Path $full -Parent) 'maester-config.json'
        return [pscustomobject]@{ Scope = 'Explicit'; ConfigPath = $(if (Test-Path -LiteralPath $config -PathType Leaf) { $config } else { $null }); LockPath = $full }
    }

    $packHome = Get-MtPackHome
    $userScope = [pscustomobject]@{ Scope = 'User'; ConfigPath = $packHome.UserConfig; LockPath = Join-Path (Split-Path -Path $packHome.UserConfig -Parent) $lockName }
    if ($Scope -eq 'User') { return $userScope }

    $start = if ($Path) { $Path } else { (Get-Location).Path }
    $found = if (Test-Path -LiteralPath $start) { @(Find-MtConfigFile -Path $start | Where-Object Kind -EQ 'Root') | Select-Object -First 1 } else { $null }
    # The user scope's own config is not a project config.
    if ($found -and [System.IO.Path]::GetFullPath($found.Path) -ne [System.IO.Path]::GetFullPath($packHome.UserConfig)) {
        return [pscustomobject]@{ Scope = 'Project'; ConfigPath = $found.Path; LockPath = Join-Path (Split-Path -Path $found.Path -Parent) $lockName }
    }
    if ($Scope -eq 'Project') {
        $folder = if (Test-Path -LiteralPath $start -PathType Container) { (Resolve-Path -LiteralPath $start).Path } else { Split-Path -Path ([System.IO.Path]::GetFullPath($start)) -Parent }
        return [pscustomobject]@{ Scope = 'Project'; ConfigPath = Join-Path $folder 'maester-config.json'; LockPath = Join-Path $folder $lockName }
    }
    $userScope
}
