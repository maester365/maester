function Read-MtLearnIndex {
    <#
    .SYNOPSIS
    Reads the URL-to-file index and the redirect answers that Update-MtLearnMirror.ps1 writes.

    .DESCRIPTION
    Update-MtLearnMirror.ps1 keeps its cache folder laid out like this:

        mirrors/<name>/   a clone of each Learn mirror
        index.json        every page of every mirror: key -> Mirror, Path (and Target when Learn redirects it)
        redirects.json    what Learn answered for linked URLs that no mirror has under that key

    Returns an object with Path (the cache folder), MirrorPath, Generated, Owner, Mirrors (name -> Repository,
    Commit, CommitDate, Pages, Include, Exclude), Pages and Redirects. Pages and Redirects are dictionaries keyed
    without regard to case.

    .PARAMETER CachePath
    The cache folder.

    .EXAMPLE
    $index = Read-MtLearnIndex -CachePath ./build/steps/.cache
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $CachePath
    )

    $indexFile = Join-Path $CachePath 'index.json'
    if (-not (Test-Path -LiteralPath $indexFile -PathType Leaf)) {
        throw "There is no Learn mirror index at '$indexFile'. Run build/steps/Update-MtLearnMirror.ps1 first."
    }
    $content = Get-Content -LiteralPath $indexFile -Raw | ConvertFrom-Json -AsHashtable -Depth 10

    $pages = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    foreach ($entry in $content['Pages'].GetEnumerator()) { $pages[$entry.Key] = $entry.Value }

    $redirects = [System.Collections.Generic.Dictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $redirectFile = Join-Path $CachePath 'redirects.json'
    if (Test-Path -LiteralPath $redirectFile -PathType Leaf) {
        $cached = Get-Content -LiteralPath $redirectFile -Raw | ConvertFrom-Json -AsHashtable -Depth 10
        if ($cached -and $cached['Redirects']) {
            foreach ($entry in $cached['Redirects'].GetEnumerator()) { $redirects[$entry.Key] = $entry.Value }
        }
    }

    $mirrors = [ordered]@{}
    if ($content['Mirrors']) { foreach ($entry in $content['Mirrors'].GetEnumerator()) { $mirrors[$entry.Key] = $entry.Value } }

    [pscustomobject]@{
        Path       = $CachePath
        MirrorPath = Join-Path $CachePath 'mirrors'
        Generated  = $content['Generated']
        Owner      = $content['Owner']
        Mirrors    = $mirrors
        Pages      = $pages
        Redirects  = $redirects
    }
}
