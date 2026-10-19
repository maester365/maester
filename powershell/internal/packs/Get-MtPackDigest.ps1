function Get-MtPackDigest {
    <#
    .SYNOPSIS
    Computes the content digest of a pack or module folder (Maester Packs design, section 5.2).

    .DESCRIPTION
    The digest is SHA-256 over the sorted list of files, one line per file: its path relative to the folder
    (with / separators), a tab, and the SHA-256 of its bytes, in lower-case hex. Paths are sorted ordinally,
    so the digest is the same on every platform. A .git folder is left out.

    The Authenticode signature block of a PowerShell file (.ps1, .psm1, .psd1, .ps1xml), from the line
    '# SIG # Begin signature block' to the end of the file, is left out of its hash, so an organisation can
    sign a pack it reviewed (section 9.11) without changing the digest in the lock file.

    Returns Digest ('sha256:<hex>') and Files (Path, Size, Sha256), in digest order.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The folder to hash.
        [Parameter(Mandatory)]
        [string] $Path
    )

    $root = (Resolve-Path -LiteralPath $Path -ErrorAction Stop).ProviderPath.TrimEnd([System.IO.Path]::DirectorySeparatorChar, [System.IO.Path]::AltDirectorySeparatorChar)
    $signed = @('.ps1', '.psm1', '.psd1', '.ps1xml')
    $latin1 = [System.Text.Encoding]::Latin1

    $files = foreach ($item in (Get-ChildItem -LiteralPath $root -Recurse -File -Force -ErrorAction Stop)) {
        $relative = [System.IO.Path]::GetRelativePath($root, $item.FullName).Replace('\', '/')
        if ($relative -eq '.git' -or $relative.StartsWith('.git/', [System.StringComparison]::Ordinal)) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
        if ($item.Extension.ToLowerInvariant() -in $signed) {
            # Latin-1 maps every byte to one character, so the cut lands on the same byte offset.
            $text = $latin1.GetString($bytes)
            $marker = [regex]::Match($text, '(\r?\n)?# SIG # Begin signature block')
            if ($marker.Success) { $bytes = $latin1.GetBytes($text.Substring(0, $marker.Index)) }
        }
        [pscustomobject]@{
            Path   = $relative
            Size   = $item.Length
            Sha256 = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
        }
    }
    # Ordinal order, so the digest never depends on the culture of the computer.
    $sorted = [System.Collections.Generic.List[object]]::new()
    foreach ($f in @($files)) { $sorted.Add($f) }
    $sorted.Sort([System.Comparison[object]] { param($a, $b) [string]::CompareOrdinal($a.Path, $b.Path) })

    $builder = [System.Text.StringBuilder]::new()
    foreach ($f in $sorted) { $null = $builder.Append($f.Path).Append("`t").Append($f.Sha256).Append("`n") }
    $hash = [System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($builder.ToString()))
    [pscustomobject]@{
        Digest = 'sha256:' + [System.Convert]::ToHexString($hash).ToLowerInvariant()
        Files  = $sorted.ToArray()
    }
}
