<#
.SYNOPSIS
Lists the step sources whose Microsoft Learn page changed since the date in its Reviewed field.

.DESCRIPTION
Each source of a step in the defender's path catalogue (powershell/assets/steps) cites a Learn page and says
when a maintainer last read it against the step (Reviewed, yyyy-MM-dd). The Learn mirrors keep every published
version of those pages in git, so their history says whether a page changed since.

For each source with a Url, the script finds the page's file through the index that Update-MtLearnMirror.ps1
writes, takes the mirror's last commit on or before the end of the Reviewed day (UTC) as the baseline, and compares
the page as it was then with the page now. Only the body counts: the crawler rewrites front matter on every page
when Learn's metadata changes, so a commit that changes only the front matter is not a change.

Each result has Step, StepTitle, File, Index, Url, Mirror, Reviewed, Status, Path, Baseline, Head, Commits (the
commits that changed the body, oldest first, each with a link to its diff), DiffLink, HistoryLink, Problems and
NeedsReview. Status is one of:

    Unchanged    the body is the same as at the baseline
    Changed      the body changed since the baseline
    New          the file did not exist at the baseline: the page moved or was published since Reviewed
    NoBaseline   the mirror has no commit from before the end of the Reviewed day
    NotFound     no mirror has the page (Detail says what Learn answered)

Problems lists what else needs a maintainer: a URL that Learn now redirects, or a Mirror that names another mirror
than the one that holds the page. A source needs review when its Status is not Unchanged or it has a problem.

Sources that cite a maintainer instead of a URL are left out. The script makes no network calls of its own; in a
blobless clone, git fetches the older versions of a page that the comparison needs.

The script exits with:

    0  no source needs review
    1  at least one source needs review
    2  the sources could not be checked (no index, a mirror missing from the cache, an unreadable catalogue)

.PARAMETER Root
The repository root.

.PARAMETER CachePath
The cache folder that Update-MtLearnMirror.ps1 writes. Defaults to build/steps/.cache.

.PARAMETER CatalogPath
The step catalogue folder. Defaults to powershell/assets/steps under -Root.

.PARAMETER Step
Check only the steps whose ID matches one of these wildcard patterns.

.PARAMETER OutputPath
A folder to write step-sources.json (every result) and step-sources.md (the steps that need review, as the
weekly issue shows them).

.PARAMETER ShowDiff
Print the change to the body of each changed page.

.EXAMPLE
./build/steps/Update-MtLearnMirror.ps1 -Links Catalog
./build/steps/Test-MtStepSource.ps1

Updates the mirrors, then lists every source and whether its page changed.

.EXAMPLE
./build/steps/Test-MtStepSource.ps1 -Step 'entra.*' -ShowDiff

Shows what changed in the pages that the Entra steps cite.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Build script output for the console')]
[CmdletBinding()]
param(
    [string] $Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,

    [string] $CachePath = (Join-Path $PSScriptRoot '.cache'),

    [string] $CatalogPath,

    [string[]] $Step,

    [string] $OutputPath,

    [switch] $ShowDiff
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($helper in Get-ChildItem -Path (Join-Path $PSScriptRoot 'helpers') -Filter '*.ps1') { . $helper.FullName }

$script:IssueMarker = '<!-- maester-step-sources -->'

function Get-MtLearnPageBody {
    <#
    .SYNOPSIS
    Returns the body of a mirror file at a commit, normalized for comparison, or $null when the file is not there.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [string] $Revision,
        [Parameter(Mandatory)] [string] $Path
    )

    $lines = Invoke-MtGit -Path $Repository -Arguments '-c', 'core.quotePath=false', 'show', "${Revision}:$Path" -AllowFailure
    if ($LASTEXITCODE -ne 0) { return $null }
    $body = (Split-MtLearnFrontMatter -Text (@($lines) -join "`n")).Body
    ((($body -split "`n") | ForEach-Object { $_.TrimEnd() }) -join "`n").Trim()
}

function Get-MtGitHubFileLink {
    <#
    .SYNOPSIS
    Builds a GitHub link to a file's diff in a commit or comparison, or to its history.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Repository,
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [ValidateSet('Commit', 'Compare', 'History')] [string] $Kind,
        [string] $From,
        [Parameter(Mandatory)] [string] $To
    )

    # GitHub names a file's diff on a commit or compare page by the SHA-256 of its path.
    $hash = [System.Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([System.Text.Encoding]::UTF8.GetBytes($Path))).ToLowerInvariant()
    $escaped = ($Path -split '/' | ForEach-Object { [System.Uri]::EscapeDataString($_) }) -join '/'
    switch ($Kind) {
        'Commit' { "https://github.com/$Repository/commit/$To#diff-$hash" }
        'Compare' { "https://github.com/$Repository/compare/$From...$To#diff-$hash" }
        'History' { "https://github.com/$Repository/commits/$To/$escaped" }
    }
}

function Test-MtStepSourceChange {
    <#
    .SYNOPSIS
    Checks one step source against the mirror history and returns its result.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [pscustomobject] $Source,
        [Parameter(Mandatory)] [pscustomobject] $Index
    )

    $result = [pscustomobject][ordered]@{
        Step        = $Source.Step
        StepTitle   = $Source.StepTitle
        File        = $Source.File
        Index       = $Source.Index
        Url         = $Source.Url
        Mirror      = $Source.Mirror
        Reviewed    = $Source.Reviewed
        Status      = 'NotFound'
        Detail      = $null
        Path        = $null
        Baseline    = $null
        Head        = $null
        Commits     = @()
        DiffLink    = $null
        HistoryLink = $null
        Problems    = @()
        NeedsReview = $true
    }
    $problems = [System.Collections.Generic.List[string]]::new()

    $page = Resolve-MtLearnPage -Index $Index -Url $Source.Url
    if (-not $page.Path) {
        $result.Detail = switch ($page.Status) {
            'Missing' { 'Learn answers 404 for this URL: the page was removed.' }
            'External' { "Learn redirects this URL to $($page.Detail)." }
            'Unresolved' { 'No mirror has this URL and Learn has not been asked about it. Run Update-MtLearnMirror.ps1.' }
            default { if ($page.Detail) { $page.Detail } else { "No mirror has the page$(if ($page.ResolvedKey -and $page.ResolvedKey -ne $page.Key) { " it redirects to ($($page.ResolvedKey))" })." } }
        }
        return $result
    }
    if ($page.Status -eq 'Redirected') {
        $problems.Add("Learn redirects this URL to https://learn.microsoft.com/$($page.ResolvedKey). Cite the new URL.")
    }
    if ($Source.Mirror -and $Source.Mirror -ne $page.Mirror) {
        $problems.Add("Mirror is $($Source.Mirror), but the page is in $($page.Mirror).")
    }
    $result.Path = $page.Path
    $result.Problems = $problems.ToArray()

    $repository = Join-Path $Index.MirrorPath $page.Mirror
    if (-not (Test-Path -LiteralPath (Join-Path $repository '.git'))) {
        throw "The mirror $($page.Mirror) is in the index but not in $($Index.MirrorPath). Run Update-MtLearnMirror.ps1."
    }
    $remote = if ($Index.Mirrors.Contains($page.Mirror) -and $Index.Mirrors[$page.Mirror]['Repository']) { $Index.Mirrors[$page.Mirror]['Repository'] } else { "$($Index.Owner)/$($page.Mirror)" }
    $head = Invoke-MtGit -Path $repository -Arguments 'rev-parse', 'HEAD' | Select-Object -First 1
    $result.Head = $head
    $result.HistoryLink = Get-MtGitHubFileLink -Repository $remote -Path $page.Path -Kind History -To $head

    # The page as it was at the end of the Reviewed day.
    $baseline = Invoke-MtGit -Path $repository -Arguments 'rev-list', '-1', '--first-parent', "--before=$($Source.Reviewed)T23:59:59Z", 'HEAD' | Select-Object -First 1
    if (-not $baseline) {
        $result.Status = 'NoBaseline'
        $result.Detail = "The mirror's history starts after $($Source.Reviewed), so it can't show what changed since. Re-read the page."
        return $result
    }
    $result.Baseline = $baseline

    $before = Get-MtLearnPageBody -Repository $repository -Revision $baseline -Path $page.Path
    if ($null -eq $before) {
        $result.Status = 'New'
        $result.Detail = "The page's file ($($page.Path)) was not in the mirror on $($Source.Reviewed): the page moved or was published since. Re-read it."
        $result.NeedsReview = $true
        return $result
    }

    # Walk the commits that touched the file, keeping those that changed the body.
    $log = @(Invoke-MtGit -Path $repository -Arguments '-c', 'core.quotePath=false', 'log', '--first-parent', '--reverse', '--format=%H%x1f%cI%x1f%s', "$baseline..HEAD", '--', $page.Path)
    $changes = [System.Collections.Generic.List[object]]::new()
    $previous = $before
    $touched = 0
    foreach ($line in $log | Where-Object { $_ }) {
        $sha, $date, $subject = $line -split [char]0x1f, 3
        $touched++
        $body = Get-MtLearnPageBody -Repository $repository -Revision $sha -Path $page.Path
        if ($body -ceq $previous) { continue }
        $changes.Add([pscustomobject][ordered]@{
                Sha     = $sha
                Date    = $date
                Subject = $subject
                Link    = Get-MtGitHubFileLink -Repository $remote -Path $page.Path -Kind Commit -To $sha
            })
        $previous = $body
    }

    $now = Get-MtLearnPageBody -Repository $repository -Revision $head -Path $page.Path
    if ($now -ceq $before) {
        $result.Status = 'Unchanged'
        $result.Detail = if ($touched -eq 0) { 'No commit since the baseline.' }
        elseif ($changes.Count -eq 0) { "$touched commit$(if ($touched -ne 1) { 's' }) since the baseline changed only the front matter." }
        else { "The page's text changed and changed back since the baseline." }
    } else {
        $result.Status = 'Changed'
        $result.Commits = $changes.ToArray()
        $last = $changes[$changes.Count - 1].Sha
        $result.DiffLink = if ($changes.Count -eq 1) { $changes[0].Link } else { Get-MtGitHubFileLink -Repository $remote -Path $page.Path -Kind Compare -From $baseline -To $last }
        $result.Detail = "$($changes.Count) commit$(if ($changes.Count -ne 1) { 's' }) changed the page's text since $($Source.Reviewed)."
    }
    $result.NeedsReview = $result.Status -ne 'Unchanged' -or $problems.Count -gt 0
    $result
}

function ConvertTo-MtStepSourceMarkdown {
    <#
    .SYNOPSIS
    Writes the results as the body of the weekly issue: the steps whose sources need review, with links to the
    changes.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Result,
        [System.Collections.IDictionary] $Mirrors = @{},
        [string] $Checked = [datetime]::UtcNow.ToString('yyyy-MM-dd', [System.Globalization.CultureInfo]::InvariantCulture)
    )

    $cell = { param($text) ([string] $text) -replace '\|', '\|' -replace '\r?\n', ' ' }
    $review = @($Result | Where-Object NeedsReview)
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add($script:IssueMarker)
    $versions = @($Mirrors.GetEnumerator() | ForEach-Object { "``$($_.Key)`` at $(([string] $_.Value['Commit']).Substring(0, [math]::Min(7, ([string] $_.Value['Commit']).Length)))" })
    $mirrorText = if ($versions.Count) { " against $($versions -join ', ')" } else { '' }
    $lines.Add("Checked on $Checked$mirrorText by ``build/steps/Test-MtStepSource.ps1``.")
    $lines.Add('')
    if ($review.Count -eq 0) {
        $lines.Add("All $(@($Result).Count) Learn sources of the step catalogue match the page each one was reviewed against.")
        return ($lines -join "`n")
    }

    $steps = @($review | Select-Object -ExpandProperty Step -Unique)
    $lines.Add("$($review.Count) of $(@($Result).Count) Learn sources need a maintainer to re-read the page, in $($steps.Count) step$(if ($steps.Count -ne 1) { 's' }).")
    $lines.Add('')
    $lines.Add('For each one, read the change on Learn, and update the step if the order it describes changed. Then set the source''s `Reviewed` to the date you read it. Commits that change only a page''s front matter are not counted.')
    foreach ($stepId in $steps) {
        $rows = @($review | Where-Object Step -EQ $stepId)
        $lines.Add('')
        $lines.Add("### ``$stepId`` $(& $cell $rows[0].StepTitle)")
        $lines.Add('')
        $lines.Add("In ``powershell/assets/steps/$($rows[0].File)``.")
        $lines.Add('')
        $lines.Add('| Source | Reviewed | What changed | Links |')
        $lines.Add('| --- | --- | --- | --- |')
        foreach ($row in $rows) {
            $what = @(
                switch ($row.Status) {
                    'Changed' { "$($row.Commits.Count) change$(if ($row.Commits.Count -ne 1) { 's' }) to the text ($((@($row.Commits) | ForEach-Object { ([string] $_.Date).Substring(0, 10) }) -join ', '))." }
                    'Unchanged' { }
                    default { $row.Detail }
                }
                $row.Problems
            ) | Where-Object { $_ }
            $commits = @($row.Commits)
            $links = @(
                if ($row.DiffLink) { "[diff]($($row.DiffLink))" }
                # A compare page can be too large to show one file, so each commit is linked as well.
                if ($commits.Count -gt 1) { 'commits ' + (($commits | ForEach-Object { "[$(([string] $_.Sha).Substring(0, 7))]($($_.Link))" }) -join ' ') }
                if ($row.HistoryLink) { "[history]($($row.HistoryLink))" }
            )
            $label = ConvertTo-MtLearnKey $row.Url
            if (-not $label) { $label = $row.Url }
            $lines.Add("| $($row.Index). [$(& $cell $label)]($($row.Url)) | $($row.Reviewed) | $(& $cell ($what -join ' ')) | $($links -join ', ') |")
        }
    }
    $lines -join "`n"
}

# Lets the unit tests dot-source the functions above without running the script.
if ($MyInvocation.InvocationName -eq '.') { return }

try {
    if (-not $CatalogPath) { $CatalogPath = Join-Path $Root 'powershell/assets/steps' }
    $index = Read-MtLearnIndex -CachePath $CachePath
    $sources = @(Get-MtStepSource -Path $CatalogPath | Where-Object Url)
    if ($Step) { $sources = @($sources | Where-Object { $id = $_.Step; $Step | Where-Object { $id -like $_ } }) }

    $results = foreach ($source in $sources) {
        Write-Host "Checking $($source.Step) source $($source.Index)"
        Test-MtStepSourceChange -Source $source -Index $index
    }
    $results = @($results)
} catch {
    Write-Error -ErrorRecord $_ -ErrorAction Continue
    exit 2
}

if ($OutputPath) {
    $null = New-Item -ItemType Directory -Path $OutputPath -Force
    ConvertTo-Json -InputObject $results -Depth 6 | Set-Content -LiteralPath (Join-Path $OutputPath 'step-sources.json') -Encoding utf8NoBOM
    ConvertTo-MtStepSourceMarkdown -Result $results -Mirrors $index.Mirrors | Set-Content -LiteralPath (Join-Path $OutputPath 'step-sources.md') -Encoding utf8NoBOM
}

if ($ShowDiff) {
    foreach ($row in $results | Where-Object Status -EQ 'Changed') {
        $repository = Join-Path $index.MirrorPath (Resolve-MtLearnPage -Index $index -Url $row.Url).Mirror
        $temp = Join-Path ([System.IO.Path]::GetTempPath()) "mt-step-source-$([guid]::NewGuid().ToString('n'))"
        $null = New-Item -ItemType Directory -Path $temp
        try {
            Set-Content -LiteralPath (Join-Path $temp 'reviewed.md') -Value (Get-MtLearnPageBody -Repository $repository -Revision $row.Baseline -Path $row.Path) -Encoding utf8NoBOM
            Set-Content -LiteralPath (Join-Path $temp 'now.md') -Value (Get-MtLearnPageBody -Repository $repository -Revision $row.Head -Path $row.Path) -Encoding utf8NoBOM
            Write-Host "`n$($row.Step) source $($row.Index): $($row.Url)"
            & git -C $temp diff --no-index --no-color --unified=2 -- reviewed.md now.md | ForEach-Object { Write-Host $_ }
        } finally {
            Remove-Item -LiteralPath $temp -Recurse -Force
        }
    }
}

$results
$needsReview = @($results | Where-Object NeedsReview)
Write-Host "$($needsReview.Count) of $($results.Count) sources need review."
exit $(if ($needsReview.Count -gt 0) { 1 } else { 0 })
