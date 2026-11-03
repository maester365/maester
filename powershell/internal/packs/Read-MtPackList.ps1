function Read-MtPackList {
    <#
    .SYNOPSIS
    Lists the built-in and installed packs from their manifests and the lock file, without loading any of them.

    .DESCRIPTION
    For Tab completion, which must be quick and must not run pack code: unlike Initialize-MtPackSet, this does
    not run the loader gate, check digests, import modules or register connectors. The built-in packs come from
    Get-MtBuiltInPack, with the tests their Catalog file lists. The installed packs are the entries of the lock
    file a command would use (Resolve-MtPackLockPath from -PackLock and -Path), with the test IDs and services
    the lock records. A lock file that cannot be read gives no installed packs.

    Each row has Id, Code, Name, Version, Publisher, BuiltIn, Installed (in the lock file), Services and Tests
    (ConvertTo-MtCompletionTest rows). The built-in packs are cached for the session, a lock file until it changes.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $PackLock,
        # The folder (or a file in it) the lock file is looked for from; the current folder by default.
        [Parameter()] [AllowNull()] [AllowEmptyString()] [string] $Path
    )

    if ($null -eq $script:__MtPackListBuiltIn) {
        $script:__MtPackListBuiltIn = @(foreach ($pack in Get-MtBuiltInPack) {
                $m = $pack.Manifest
                if (-not $m) { continue }
                $tests = @()
                if ($m.PSObject.Properties['Catalog'] -and $m.Catalog -is [string]) {
                    $file = Join-Path $pack.Root $m.Catalog
                    if (Test-Path -LiteralPath $file -PathType Leaf) {
                        $tests = @(ConvertTo-MtCompletionTest -Test @((Get-Content -LiteralPath $file -Raw | ConvertFrom-Json).Tests) -Source Pack -Pack $pack.Id)
                    }
                }
                [pscustomobject]@{
                    Id        = [string]$pack.Id
                    Code      = [string]$m.Code
                    Name      = [string]$m.Name
                    Version   = [string]$m.Version
                    Publisher = [string]$m.Publisher
                    BuiltIn   = $true
                    Installed = $false
                    Services  = [string[]]@(@($m.Connectors) | Where-Object { $_ -and $_.Service } | ForEach-Object { [string]$_.Service })
                    Tests     = $tests
                }
            })
    }

    $start = if ($Path -and (Test-Path -LiteralPath $Path -PathType Leaf)) { Split-Path -Path (Resolve-Path -LiteralPath $Path).Path -Parent } else { $Path }
    $lockPath = (Resolve-MtPackLockPath -PackLock $PackLock -Path $start).LockPath
    $installed = @()
    if ($lockPath -and (Test-Path -LiteralPath $lockPath -PathType Leaf)) {
        $stamp = [System.IO.File]::GetLastWriteTimeUtc($lockPath).Ticks
        if (-not $script:__MtPackListLocks) { $script:__MtPackListLocks = @{} }
        $cached = $script:__MtPackListLocks[$lockPath]
        if ($cached -and $cached.Stamp -eq $stamp) {
            $installed = $cached.Packs
        } else {
            $entries = try { @((Read-MtPackLock -Path $lockPath).Packs) } catch { Write-Debug $_.Exception.Message; @() }
            $installed = @(foreach ($entry in $entries) {
                    if (-not $entry.Id) { continue }
                    $testIds = @(@($entry.Tests) | Where-Object { $_ } | ForEach-Object { [string]$_ })
                    # An installed pack's tests are MP.<code>.<n>, so the code is known from them.
                    $code = if ($entry.PSObject.Properties['Code'] -and $entry.Code) { [string]$entry.Code } else {
                        $testIds | Where-Object { $_ -match '^MP\.([^.]+)\.' } | ForEach-Object { $Matches[1] } | Select-Object -First 1
                    }
                    [pscustomobject]@{
                        Id        = [string]$entry.Id
                        Code      = [string]$code
                        Name      = if ($entry.PSObject.Properties['Name'] -and $entry.Name) { [string]$entry.Name } else { [string]$entry.Id }
                        Version   = [string]$entry.Version
                        Publisher = [string]$entry.Publisher
                        BuiltIn   = $false
                        Installed = $true
                        Services  = [string[]]@(@($entry.Services) | Where-Object { $_ } | ForEach-Object { if ($_ -is [string]) { $_ } else { [string]$_.Service } })
                        Tests     = @(ConvertTo-MtCompletionTest -Test @($testIds | ForEach-Object { [pscustomobject]@{ Id = $_ } }) -Source Pack -Pack ([string]$entry.Id))
                    }
                })
            $script:__MtPackListLocks[$lockPath] = @{ Stamp = $stamp; Packs = $installed }
        }
    }

    $installedIds = @($installed | ForEach-Object { $_.Id })
    foreach ($pack in $script:__MtPackListBuiltIn) {
        # A built-in pack whose Gallery modules were saved has a lock entry too; it is still the built-in pack.
        if ($installedIds -contains $pack.Id) { $copy = $pack.PSObject.Copy(); $copy.Installed = $true; $copy } else { $pack }
    }
    $installed | Where-Object { -not ($script:__MtPackListBuiltIn.Id -contains $_.Id) }
}
