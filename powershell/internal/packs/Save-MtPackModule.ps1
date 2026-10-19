function Save-MtPackModule {
    <#
    .SYNOPSIS
    Saves the PowerShell Gallery modules a pack declares, and returns the pinned module closure for the lock file (Maester Packs design, section 4.2).

    .DESCRIPTION
    Each module in Uses.Modules is saved at its exact version with Save-PSResource (Save-Module when
    PSResourceGet is not installed) into the pack home's modules folder, never the user's module folder, so
    it cannot shadow a module Maester loads. Saving runs no code from the module. The modules it requires
    are saved with it, and the closure, every module and version reached through RequiredModules, is
    returned with the digest of each folder (Get-MtPackDigest), which the loader checks before any import.

    A module that is already in the store is not saved again; its digest is computed from the store.

    With -AllowExternal (PackPolicy.AllowExternalEnvironments), a module the user installed themselves at
    the exact version is used where it is when it is not in the store: it is returned with Source External
    and its digest at approval, so a later change to it stops the pack until it is approved again
    (Sam Erde's review of the design, which asked that the lock always identify the code that is imported).

    Returns rows with Name, Version, Digest, Source (PSGallery or External) and Path.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Module,
        [Parameter()] [switch] $AllowExternal,
        # The module repository to save from.
        [Parameter()] [string] $Repository = 'PSGallery'
    )

    $store = (Get-MtPackHome).Modules
    $closure = [ordered]@{}
    $queue = [System.Collections.Generic.Queue[object]]::new()
    foreach ($m in $Module) { $queue.Enqueue([pscustomobject]@{ Name = [string]$m.Name; Version = [string]$m.Version; Exact = $true }) }

    while ($queue.Count -gt 0) {
        $item = $queue.Dequeue()
        $key = "$($item.Name.ToLowerInvariant())@$($item.Version)"
        if ($closure.Contains($key)) { continue }
        $path = Find-MtPackModuleFolder -Name $item.Name -Version $item.Version -Root $store
        $source = 'PSGallery'
        if (-not $path) {
            $external = if ($AllowExternal) { Find-MtPackModuleFolder -Name $item.Name -Version $item.Version } else { $null }
            if ($external) {
                $path = $external; $source = 'External'
            } elseif ($PSCmdlet.ShouldProcess("$($item.Name) $($item.Version)", "Save the module from $Repository")) {
                Save-MtPackModuleFromGallery -Name $item.Name -Version $item.Version -Store $store -Repository $Repository
                $path = Find-MtPackModuleFolder -Name $item.Name -Version $item.Version -Root $store
            }
        }
        if (-not $path) { throw "The module $($item.Name) $($item.Version) could not be saved from $Repository." }

        $closure[$key] = [pscustomobject]@{ Name = $item.Name; Version = $item.Version; Digest = (Get-MtPackDigest -Path $path).Digest; Source = $source; Path = $path }
        # The modules it requires, at the version it names (the lowest it accepts, as Save-PSResource resolves it in the store).
        foreach ($required in (Get-MtPackModuleRequirement -Path $path)) {
            $version = $required.Version
            if (-not $version) {
                $saved = @(Get-ChildItem -LiteralPath (Join-Path $store $required.Name) -Directory -ErrorAction SilentlyContinue | Sort-Object { [version]($_.Name -replace '-.*$', '') } -Descending)
                $version = if ($saved) { $saved[0].Name } else { $null }
            }
            if ($version) { $queue.Enqueue([pscustomobject]@{ Name = $required.Name; Version = $version; Exact = $false }) }
            elseif ($required.Name -notmatch '^(Microsoft\.Graph\.Authentication|Az\.Accounts)$') {
                Write-Warning "The module $($item.Name) requires $($required.Name), which was not saved with it. It loads from your own module folder and is not checked."
            }
        }
    }
    $closure.Values
}

function Save-MtPackModuleFromGallery {
    <#
    .SYNOPSIS
    Saves one module at one version, and the modules it requires, into the pack module store, read-only.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter(Mandatory)] [string] $Store,
        [Parameter(Mandatory)] [string] $Repository
    )

    $staging = Join-Path ([System.IO.Path]::GetTempPath()) "maester-module-$([guid]::NewGuid().ToString('n'))"
    $null = New-Item -Path $staging -ItemType Directory -Force
    try {
        if (Get-Command -Name Save-PSResource -ErrorAction SilentlyContinue) {
            Save-PSResource -Name $Name -Version "[$Version]" -Repository $Repository -Path $staging -TrustRepository -SkipDependencyCheck:$false -Quiet -ErrorAction Stop
        } elseif (Get-Command -Name Save-Module -ErrorAction SilentlyContinue) {
            Save-Module -Name $Name -RequiredVersion $Version -Repository $Repository -Path $staging -Force -ErrorAction Stop
        } else {
            throw 'Neither Save-PSResource nor Save-Module is available, so the module could not be saved. Install Microsoft.PowerShell.PSResourceGet.'
        }
        foreach ($moduleFolder in (Get-ChildItem -LiteralPath $staging -Directory)) {
            foreach ($versionFolder in (Get-ChildItem -LiteralPath $moduleFolder.FullName -Directory)) {
                $target = Join-Path (Join-Path $Store $moduleFolder.Name) $versionFolder.Name
                if (Test-Path -LiteralPath $target) { continue }
                $null = New-Item -Path (Split-Path -Path $target -Parent) -ItemType Directory -Force
                Move-Item -LiteralPath $versionFolder.FullName -Destination $target
                Protect-MtPackFolder -Path $target
            }
        }
    } finally {
        Remove-Item -LiteralPath $staging -Recurse -Force -ErrorAction SilentlyContinue
    }
}

function Find-MtPackModuleFolder {
    <#
    .SYNOPSIS
    Returns the folder of a module at an exact version: under -Root (<Name>/<Version>), or on PSModulePath when -Root is not given.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Version,
        [Parameter()] [string] $Root
    )

    if ($Root) {
        $folder = Join-Path (Join-Path $Root $Name) $Version
        if (Test-Path -LiteralPath (Join-Path $folder "$Name.psd1") -PathType Leaf) { return $folder }
        # Save-PSResource writes the version without a prerelease label.
        $short = Join-Path (Join-Path $Root $Name) ($Version -replace '-.*$', '')
        if (Test-Path -LiteralPath (Join-Path $short "$Name.psd1") -PathType Leaf) { return $short }
        return $null
    }
    $found = Get-Module -Name $Name -ListAvailable -ErrorAction SilentlyContinue | Where-Object { [string]$_.Version -eq ($Version -replace '-.*$', '') } | Select-Object -First 1
    if ($found) { $found.ModuleBase } else { $null }
}

function Get-MtPackModuleRequirement {
    <#
    .SYNOPSIS
    Reads the RequiredModules of a saved module's manifest, without importing it: Name and the version it names, if any.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param([Parameter(Mandatory)] [string] $Path)

    $manifest = Get-ChildItem -LiteralPath $Path -Filter '*.psd1' -File | Where-Object { $_.BaseName -eq (Split-Path -Path (Split-Path -Path $Path -Parent) -Leaf) } | Select-Object -First 1
    if (-not $manifest) { $manifest = Get-ChildItem -LiteralPath $Path -Filter '*.psd1' -File | Select-Object -First 1 }
    if (-not $manifest) { return }
    try { $data = Import-PowerShellDataFile -LiteralPath $manifest.FullName -ErrorAction Stop } catch { return }
    foreach ($r in @($data.RequiredModules)) {
        if ($r -is [string]) { [pscustomobject]@{ Name = $r; Version = $null } }
        elseif ($r -is [hashtable]) {
            $version = if ($r.RequiredVersion) { $r.RequiredVersion } elseif ($r.ModuleVersion) { $r.ModuleVersion } else { $null }
            [pscustomobject]@{ Name = [string]$r.ModuleName; Version = $(if ($version) { [string]$version } else { $null }) }
        }
    }
}

function Protect-MtPackFolder {
    <#
    .SYNOPSIS
    Makes every file under a folder read-only, so a change to the store has to be deliberate (Maester Packs design, section 5.2).
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)] [string] $Path)

    foreach ($file in (Get-ChildItem -LiteralPath $Path -Recurse -File -Force)) {
        if ($IsWindows) {
            $file.IsReadOnly = $true
        } else {
            $mode = [System.IO.File]::GetUnixFileMode($file.FullName)
            $writable = [System.IO.UnixFileMode]::UserWrite -bor [System.IO.UnixFileMode]::GroupWrite -bor [System.IO.UnixFileMode]::OtherWrite
            [System.IO.File]::SetUnixFileMode($file.FullName, $mode -band (-bnot $writable))
        }
    }
}
