function Get-MtPackDigest {
    <#
    .SYNOPSIS
    Computes the content digest of a pack or module folder (Maester Packs design, section 5.2).

    .DESCRIPTION
    The digest is SHA-256 over the sorted list of files, one line per file: its path relative to the folder
    (with / separators), a tab, and the SHA-256 of its bytes, in lower-case hex. Paths are sorted ordinally,
    so the digest is the same on every platform. A .git folder is left out.

    The Authenticode signature block of a PowerShell file (.ps1, .psm1, .psd1, .ps1xml), from the line
    '# SIG # Begin signature block' through a terminal, comment-only end marker, is left out of its hash, so an organisation can
    sign a pack it reviewed (section 9.11) without changing the digest in the lock file.
    Marker text in strings or malformed trailers is hashed normally. Named data streams are refused,
    including Zone.Identifier, because their content is not represented by the portable file digest.

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

    $items = @((Get-Item -LiteralPath $root -Force -ErrorAction Stop)) + @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction Stop)
    $files = foreach ($item in $items) {
        $relative = [System.IO.Path]::GetRelativePath($root, $item.FullName).Replace('\', '/')
        if ($relative -eq '.git' -or $relative.StartsWith('.git/', [System.StringComparison]::Ordinal)) { continue }
        if ($item.Name.Contains(':')) { throw "The pack contains an unsafe path: $($item.FullName)." }
        if ($IsWindows) {
            $streams = @(Get-Item -LiteralPath $item.FullName -Stream '*' -ErrorAction Stop | Where-Object Stream -NE ':$DATA')
            if ($streams.Count -gt 0) { throw "The pack contains an alternate data stream: $($item.FullName):$($streams[0].Stream)." }
        }
        if ($item.PSIsContainer) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($item.FullName)
        if ($item.Extension.ToLowerInvariant() -in $signed) {
            # Latin-1 maps every byte to one character, so the cut lands on the same byte offset.
            $text = $latin1.GetString($bytes)
            $marker = [regex]::Match($text, '(?m)^# SIG # Begin signature block\r?\n(?:# [A-Za-z0-9+/=]+\r?\n)+# SIG # End signature block(?:\r?\n)?\z')
            if ($marker.Success) {
                # A line-shaped marker can still be inside a here-string or block comment.
                $tokens = $null
                $parseErrors = $null
                $null = [System.Management.Automation.Language.Parser]::ParseInput($text, [ref]$tokens, [ref]$parseErrors)
                $comment = $tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.StartOffset -eq $marker.Index } | Select-Object -First 1
                if ($comment) {
                    $cut = $marker.Index
                    if ($cut -gt 0 -and $text[$cut - 1] -eq "`n") {
                        $cut--
                        if ($cut -gt 0 -and $text[$cut - 1] -eq "`r") { $cut-- }
                    }
                    $bytes = $latin1.GetBytes($text.Substring(0, $cut))
                }
            }
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
