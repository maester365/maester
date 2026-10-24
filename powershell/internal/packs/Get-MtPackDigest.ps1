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
    Marker text in strings or malformed trailers is hashed normally.

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

    $Items = @((Get-Item -LiteralPath $root -Force -ErrorAction Stop)) + @(Get-ChildItem -LiteralPath $root -Recurse -Force -ErrorAction Stop)
    $files = foreach ($Item in $Items) {
        $Relative = [System.IO.Path]::GetRelativePath($root, $Item.FullName).Replace('\', '/')
        if ($Relative -eq '.git' -or $Relative.StartsWith('.git/', [System.StringComparison]::Ordinal)) { continue }
        if ($Item.Name.Contains(':')) { throw "The pack contains an unsafe path: $($Item.FullName)." }
        if ($Item.PSIsContainer) { continue }
        $bytes = [System.IO.File]::ReadAllBytes($Item.FullName)
        if ($Item.Extension.ToLowerInvariant() -in $signed) {
            # Latin-1 maps every byte to one character, so the cut lands on the same byte offset.
            $Text = $latin1.GetString($bytes)
            $Marker = [regex]::Match($Text, '(?m)^# SIG # Begin signature block\r?\n(?:# [A-Za-z0-9+/=]+\r?\n)+# SIG # End signature block(?:\r?\n)?\z')
            if ($Marker.Success) {
                # A line-shaped marker can still be inside a here-string or block comment.
                $Tokens = $null
                $ParseErrors = $null
                $null = [System.Management.Automation.Language.Parser]::ParseInput($Text, [ref]$Tokens, [ref]$ParseErrors)
                $Comment = $Tokens | Where-Object { $_.Kind -eq 'Comment' -and $_.Extent.StartOffset -eq $Marker.Index } | Select-Object -First 1
                if ($Comment) {
                    $Cut = $Marker.Index
                    if ($Cut -gt 0 -and $Text[$Cut - 1] -eq "`n") {
                        $Cut--
                        if ($Cut -gt 0 -and $Text[$Cut - 1] -eq "`r") { $Cut-- }
                    }
                    $bytes = $latin1.GetBytes($Text.Substring(0, $Cut))
                }
            }
        }
        [pscustomobject]@{
            Path   = $Relative
            Size   = $Item.Length
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
