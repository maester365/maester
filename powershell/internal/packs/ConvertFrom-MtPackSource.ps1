function ConvertFrom-MtPackSource {
    <#
    .SYNOPSIS
    Parses the <source> of Install-MtPack (Maester Packs design, section 5.1).

    .DESCRIPTION
    Accepts owner/repo, owner/repo/<folder>, either with @<tag> or @<commit>, a GitHub URL
    (https://github.com/owner/repo, or .../tree/<ref>/<folder>), a local folder, or the Id of a pack that
    ships with Maester. A folder that exists wins over the GitHub reading of the same text.

    Returns Kind (GitHub, Local or BuiltIn), Owner, Repo, Folder, Ref, Path (Local and BuiltIn) and Display,
    the canonical text recorded as the pack's Source: github.com/owner/repo[/folder], or the full path.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Source
    )

    $result = { param($kind, $owner, $repo, $folder, $ref, $path)
        $display = switch ($kind) {
            'GitHub' { "github.com/$owner/$repo$(if ($folder) { "/$folder" })" }
            default { $path }
        }
        [pscustomobject]@{ Kind = $kind; Owner = $owner; Repo = $repo; Folder = $folder; Ref = $ref; Path = $path; Display = $display }
    }

    $builtIn = Get-MtBuiltInPack | Where-Object { $_.Id -eq $Source } | Select-Object -First 1
    if ($builtIn) { return & $result 'BuiltIn' $null $null $null $null $builtIn.Root }

    if ((Test-Path -LiteralPath $Source -PathType Container) -and ($Source -match '^(\.|~|/|\\|[A-Za-z]:)' -or -not ($Source -match '^[A-Za-z0-9-]+/[A-Za-z0-9._-]+'))) {
        return & $result 'Local' $null $null $null $null (Resolve-Path -LiteralPath $Source).Path
    }

    $text = $Source.Trim()
    $ref = $null
    if ($text -match '^(?:https?://)?github\.com/([^/]+)/([^/@#?]+?)(?:\.git)?(?:/tree/([^/]+)(?:/(.+?))?)?/?$') {
        return & $result 'GitHub' $Matches[1] $Matches[2] $(if ($Matches[4]) { $Matches[4].Trim('/') }) $(if ($Matches[3]) { $Matches[3] })
    }
    if ($text -match '^(?:github\.com/)?([A-Za-z0-9](?:[A-Za-z0-9-]{0,38}))/([A-Za-z0-9._-]+?)((?:/[A-Za-z0-9._-]+)*)(?:@([A-Za-z0-9._/-]+))?$') {
        $folder = if ($Matches[3]) { $Matches[3].Trim('/') } else { $null }
        $ref = if ($Matches[4]) { $Matches[4] } else { $null }
        if ($folder -and (@($folder.Split('/')) -contains '..')) { throw "The pack source '$Source' is not valid: a folder cannot contain '..'." }
        return & $result 'GitHub' $Matches[1] $Matches[2] $folder $ref
    }
    if (Test-Path -LiteralPath $Source -PathType Container) {
        return & $result 'Local' $null $null $null $null (Resolve-Path -LiteralPath $Source).Path
    }
    throw "The pack source '$Source' is not a GitHub repository (owner/repo, owner/repo/folder or a github.com URL), a folder, or a pack that ships with Maester."
}
