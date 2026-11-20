function Get-MtReviewPullRequestFile {
    <#
    .SYNOPSIS
    Selects safe test paths for review and head downloads from the pull request files API.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [AllowEmptyCollection()]
        [object[]] $Changed,

        [int] $MaxFiles = 400
    )

    $review = [System.Collections.Generic.List[string]]::new()
    $download = [System.Collections.Generic.List[string]]::new()
    $seen = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::Ordinal)
    foreach ($file in $Changed) {
        $paths = @([string] $file.filename)
        if ($file.status -eq 'renamed' -and $file.PSObject.Properties['previous_filename'] -and $file.previous_filename) {
            $paths += [string] $file.previous_filename
        }
        foreach ($path in $paths) {
            if ($path -notmatch '^tests/[A-Za-z0-9._/-]+/Test\.[A-Za-z0-9._-]+\.(ps1|md)$' -or $path -match '\.\.') { continue }
            if ($seen.Add($path)) { $review.Add($path) }
            if ($path -eq $file.filename -and $file.status -ne 'removed' -and $path -notin $download) {
                $download.Add($path)
            }
        }
    }
    if ($review.Count -gt $MaxFiles) {
        throw "The pull request changes $($review.Count) test files, more than this job downloads. Ask a maintainer to review the attributes."
    }
    [pscustomobject]@{ Review = $review.ToArray(); Download = $download.ToArray() }
}
