function Get-MtBuiltInPack {
    <#
    .SYNOPSIS
    Returns the packs that ship with Maester: every folder under packs/ that holds a maester-pack.json.

    .DESCRIPTION
    In the built module the packs are in packs/ next to Maester.psd1; in a source checkout, in the
    repository's packs/ folder. They are part of the module, so they are trusted as the module is: they need
    no lock entry and no approval, and their files are checked against the module rather than a digest.
    Gallery modules they declare in Uses.Modules are still saved and pinned in the lock file, like any pack's
    (Install-MtPack <Id>).

    Each row has Id, Root, Manifest and Errors (from Read-MtPackManifest). Cached for the session.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # Read the folders again.
        [Parameter()]
        [switch] $Refresh
    )

    if ($null -ne $script:__MtBuiltInPacks -and -not $Refresh) { return $script:__MtBuiltInPacks }
    $moduleBase = $ExecutionContext.SessionState.Module.ModuleBase
    $root = @((Join-Path $moduleBase 'packs'), (Join-Path $moduleBase '../packs')) | Where-Object { Test-Path -LiteralPath $_ -PathType Container } | Select-Object -First 1
    $packs = @()
    if ($root) {
        $packs = @(foreach ($folder in (Get-ChildItem -LiteralPath $root -Directory | Sort-Object Name)) {
                if (-not (Test-Path -LiteralPath (Join-Path $folder.FullName 'maester-pack.json') -PathType Leaf)) { continue }
                $read = Read-MtPackManifest -Path $folder.FullName -Official
                [pscustomobject]@{
                    Id       = if ($read.Manifest) { [string]$read.Manifest.Id } else { $folder.Name }
                    Root     = $folder.FullName
                    Manifest = $read.Manifest
                    Errors   = $read.Errors
                }
            })
    }
    $script:__MtBuiltInPacks = $packs
    $script:__MtBuiltInPacks
}
