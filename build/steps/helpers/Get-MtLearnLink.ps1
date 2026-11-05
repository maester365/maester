function Get-MtLearnLink {
    <#
    .SYNOPSIS
    Lists the Microsoft Learn pages that check guides and step sources link to.

    .DESCRIPTION
    Finds the Learn links in the check guides (tests/**/Test.*.md) and in the Url of each step source in the
    catalogue, and returns one object per page: Key (see ConvertTo-MtLearnKey), Url (the first link seen, without
    its anchor or query) and From, the places that link to it. Each place has Kind (Guide or Source), Id (the test ID
    of a guide, or the step ID of a source), File (relative to -Root) and Line (guides only).

    .PARAMETER Root
    The repository root.

    .PARAMETER Links
    Which links to read: All (the default), Guides or Catalog.

    .PARAMETER CatalogPath
    The step catalogue folder. Defaults to powershell/assets/steps under -Root.

    .EXAMPLE
    Get-MtLearnLink -Root . -Links Catalog
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Root,

        [ValidateSet('All', 'Guides', 'Catalog')]
        [string] $Links = 'All',

        [string] $CatalogPath
    )

    if (-not $CatalogPath) { $CatalogPath = Join-Path $Root 'powershell/assets/steps' }
    $pages = [ordered]@{}
    $add = {
        param([string] $url, [hashtable] $from)
        $key = ConvertTo-MtLearnKey $url
        # Not a Learn URL, or the site's home page.
        if ([string]::IsNullOrEmpty($key)) { return }
        if (-not $pages.Contains($key)) {
            $pages[$key] = [pscustomobject][ordered]@{
                Key  = $key
                Url  = ($url -split '[?#]')[0]
                From = [System.Collections.Generic.List[object]]::new()
            }
        }
        $pages[$key].From.Add([pscustomobject]$from)
    }

    if ($Links -in 'All', 'Catalog') {
        foreach ($source in Get-MtStepSource -Path $CatalogPath | Where-Object Url) {
            & $add $source.Url ([ordered]@{ Kind = 'Source'; Id = $source.Step; File = "powershell/assets/steps/$($source.File)"; Line = $null })
        }
    }

    if ($Links -in 'All', 'Guides') {
        $testsFolder = Join-Path $Root 'tests'
        $guides = Get-ChildItem -LiteralPath $testsFolder -Recurse -File -Filter 'Test.*.md' -ErrorAction SilentlyContinue |
            Sort-Object FullName
        $pattern = [regex]::new('https?://(?:learn|docs)\.microsoft\.com/[^\s)<>"''`\]]+', 'IgnoreCase')
        foreach ($guide in $guides) {
            $relative = [System.IO.Path]::GetRelativePath($Root, $guide.FullName) -replace '\\', '/'
            $id = $guide.Name -replace '^Test\.', '' -replace '\.md$', ''
            $lineNumber = 0
            foreach ($line in [System.IO.File]::ReadLines($guide.FullName)) {
                $lineNumber++
                foreach ($match in $pattern.Matches($line)) {
                    $url = $match.Value.TrimEnd('.', ',', ';', ':', '*', '_')
                    & $add $url ([ordered]@{ Kind = 'Guide'; Id = $id; File = $relative; Line = $lineNumber })
                }
            }
        }
    }

    $pages.Values
}
