function Expand-MtPackArchive {
    <#
    .SYNOPSIS
    Extracts a GitHub zip archive of a repository into a folder, refusing anything a pack may not contain.

    .DESCRIPTION
    GitHub's archives hold one top folder (owner-repo-commit). Its content, or only -Folder within it, is
    written to -Destination. Nothing in the archive runs, and it is never handed to an external tool:

    - An entry whose path is absolute or contains '..' or ':' stops the extraction (including Windows data streams).
    - A symbolic link stops it (Maester Packs design, section 4.3): links unpack differently on each
      platform and could point outside the pack.
    - At most 50 MB in total, 20 MB per file and 10,000 entries, counted from the sizes the archive
      declares before anything is written.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Archive,
        [Parameter(Mandatory)] [string] $Destination,
        # A folder inside the repository: only it is extracted.
        [Parameter()] [string] $Folder
    )

    Add-Type -AssemblyName System.IO.Compression -ErrorAction SilentlyContinue
    $zip = [System.IO.Compression.ZipFile]::OpenRead($Archive)
    try {
        $entries = @($zip.Entries)
        if ($entries.Count -eq 0) { throw 'The archive is empty.' }
        if ($entries.Count -gt 10000) { throw "The archive has $($entries.Count) entries; a pack can have at most 10,000." }
        $top = $entries[0].FullName.Split('/')[0]
        $prefix = "$top/"
        if ($Folder) { $prefix = "$top/$($Folder.Trim('/'))/" }

        $selected = [System.Collections.Generic.List[object]]::new()
        $total = 0L
        foreach ($entry in $entries) {
            $name = $entry.FullName.Replace('\', '/')
            if ($name.StartsWith('/') -or $name.Contains(':') -or @($name.Split('/')) -contains '..') { throw "The archive has an unsafe path: $name." }
            if (-not $name.StartsWith($prefix, [System.StringComparison]::Ordinal)) { continue }
            $relative = $name.Substring($prefix.Length)
            if (-not $relative) { continue }
            # Unix file mode in the high 16 bits; 0xA000 is a symbolic link.
            if ((($entry.ExternalAttributes -shr 16) -band 0xF000) -eq 0xA000) { throw "The pack contains a symbolic link, which is not allowed: $relative." }
            if ($entry.Length -gt 20MB) { throw "$relative is $([math]::Round($entry.Length / 1MB, 1)) MB; at most 20 MB is allowed per file." }
            $total += $entry.Length
            if ($total -gt 50MB) { throw 'The pack is larger than 50 MB.' }
            $selected.Add([pscustomobject]@{ Entry = $entry; Relative = $relative })
        }
        if ($selected.Count -eq 0) { throw $(if ($Folder) { "The repository has no folder '$Folder'." } else { 'The archive holds no files.' }) }

        $null = New-Item -Path $Destination -ItemType Directory -Force
        $destinationFull = [System.IO.Path]::GetFullPath($Destination).TrimEnd([System.IO.Path]::DirectorySeparatorChar) + [System.IO.Path]::DirectorySeparatorChar
        foreach ($item in $selected) {
            $target = [System.IO.Path]::GetFullPath((Join-Path $Destination $item.Relative))
            if (-not $target.StartsWith($destinationFull, [System.StringComparison]::Ordinal)) { throw "The archive has an unsafe path: $($item.Relative)." }
            if ($item.Relative.EndsWith('/')) { $null = New-Item -Path $target -ItemType Directory -Force; continue }
            $null = New-Item -Path (Split-Path -Path $target -Parent) -ItemType Directory -Force
            [System.IO.Compression.ZipFileExtensions]::ExtractToFile($item.Entry, $target, $false)
        }
    } finally {
        $zip.Dispose()
    }
}
