function Split-MtLearnFrontMatter {
    <#
    .SYNOPSIS
    Splits a mirrored Learn page into its front matter and its body.

    .DESCRIPTION
    A page in a Learn mirror starts with YAML front matter between two --- lines: the page's title, canonicalUrl,
    ms.topic, source_path (the file in the original repository) and original_content_git_url, among others. The
    rest is the page as Learn serves it as Markdown, with includes expanded.

    Returns an object with:

    - FrontMatter: the top-level scalar keys of the front matter (key: value lines), as an ordered dictionary.
      Lists and nested values are left out.
    - Body: the text after the front matter, with Windows line endings changed to `n.
    - BodyLine: the 1-based line number, in the file, of the body's first line.

    A page with no front matter has an empty FrontMatter and the whole text as Body.

    .PARAMETER Text
    The page's text.

    .EXAMPLE
    Split-MtLearnFrontMatter -Text (Get-Content -Raw ./overview.md)
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text
    )

    $normalized = $Text -replace "`r`n", "`n"
    $lines = $normalized -split "`n"
    $frontMatter = [ordered]@{}
    $bodyIndex = 0
    if ($lines.Count -gt 1 -and $lines[0].TrimEnd() -eq '---') {
        for ($i = 1; $i -lt $lines.Count; $i++) {
            if ($lines[$i].TrimEnd() -eq '---') { $bodyIndex = $i + 1; break }
            $pair = [regex]::Match($lines[$i], '^(?<key>[A-Za-z0-9_.\-]+):[ \t]*(?<value>.*)$')
            if ($pair.Success -and $pair.Groups['value'].Value -ne '') {
                $frontMatter[$pair.Groups['key'].Value] = $pair.Groups['value'].Value.Trim().Trim('"', "'")
            }
        }
        # An opening --- with no closing one is not front matter.
        if ($bodyIndex -eq 0) { $frontMatter = [ordered]@{} }
    }

    [pscustomobject]@{
        FrontMatter = $frontMatter
        Body        = ($lines | Select-Object -Skip $bodyIndex) -join "`n"
        BodyLine    = $bodyIndex + 1
    }
}
