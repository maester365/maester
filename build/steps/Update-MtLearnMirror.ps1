<#
.SYNOPSIS
Clones or updates the Microsoft Learn mirrors and writes the URL-to-file index that the step tooling reads.

.DESCRIPTION
The defender's path catalogue (powershell/assets/steps, docs/proposals/defenders-path.md section 13) cites Learn
pages. Nine public mirrors built with merill/learn-mirror keep those pages in git: Learn is crawled four times a day
and each run that finds changed pages commits them. This script keeps a clone of each mirror in a cache folder and
writes what the other scripts in build/steps need to find a page's file without the network:

    <CachePath>/mirrors/<name>/   a blobless clone of each mirror (history and the current files)
    <CachePath>/index.json        every page of every mirror: key -> Mirror, Path (and Target when Learn
                                  redirects the page to another one)
    <CachePath>/redirects.json    what Learn answered for linked URLs that no mirror has under that key

A key is a Learn URL's path with no locale, query, anchor or trailing slash, in lowercase. The index is read from
each mirror's .learn-mirror/state.json, which maps every page URL the crawler knows to the file it wrote, and the
mirror's learn-mirror.config.json, whose include and exclude patterns say which URLs the mirror covers. A mirror
with no state file is indexed from the canonicalUrl in each page's front matter.

Check guides still link many pages by an old URL (mem/intune/..., microsoft-365/security/defender/...,
azure/active-directory/...), which Learn redirects. For each URL that the check guides (tests/**/Test.*.md) or
the step sources link and that no mirror has under that key, the script asks Learn where it goes and caches the
answer for -RedirectMaxAge days. Learn's answers to HEAD requests often leave the redirect out (on 5 November 2026
HEAD returned 200 for microsoft-365/security/defender/microsoft-secure-score, which GET redirects), so each lookup
is a GET that reads only the response headers and never the page. Redirects are followed one hop at a time, at
most -RequestsPerSecond requests a second.

The cache folder is ignored by git. Nothing outside it is written.

.PARAMETER Root
The repository root. Check guides are read from tests/ and step sources from powershell/assets/steps.

.PARAMETER CachePath
The cache folder. Defaults to build/steps/.cache.

.PARAMETER Mirror
The mirrors to clone and index. Defaults to all nine.

.PARAMETER Owner
The GitHub account that holds the mirrors.

.PARAMETER Links
Which links to resolve through Learn's redirects: All (check guides and step sources, the default), Guides,
Catalog or None.

.PARAMETER RedirectMaxAge
How many days a cached answer from Learn is used before it is asked again. 0 asks again for every URL.

.PARAMETER RequestsPerSecond
The most requests a second sent to Learn.

.PARAMETER NoFetch
Use the clones already in the cache folder, without fetching. A mirror that has not been cloned is left out.

.EXAMPLE
./build/steps/Update-MtLearnMirror.ps1

Clones or updates the nine mirrors, writes the index and resolves the links of every check guide and step source.

.EXAMPLE
./build/steps/Update-MtLearnMirror.ps1 -Mirror entra-docs-mirror, intune-docs-mirror -Links Catalog

Updates two mirrors and resolves only the step sources' links. The weekly step-sources workflow runs it like this.
#>
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingWriteHost', '', Justification = 'Build script output for the console')]
[CmdletBinding()]
param(
    [string] $Root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path,

    [string] $CachePath = (Join-Path $PSScriptRoot '.cache'),

    [ValidateSet('entra-docs-mirror', 'intune-docs-mirror', 'defender-docs-mirror', 'security-docs-mirror', 'purview-docs-mirror',
        'teams-docs-mirror', 'sharepoint-docs-mirror', 'exchange-docs-mirror', 'windows-server-docs-mirror')]
    [string[]] $Mirror = @('entra-docs-mirror', 'intune-docs-mirror', 'defender-docs-mirror', 'security-docs-mirror', 'purview-docs-mirror',
        'teams-docs-mirror', 'sharepoint-docs-mirror', 'exchange-docs-mirror', 'windows-server-docs-mirror'),

    [ValidatePattern('^[A-Za-z0-9](?:[A-Za-z0-9]|-(?=[A-Za-z0-9])){0,38}$')]
    [string] $Owner = 'merill',

    [ValidateSet('All', 'Guides', 'Catalog', 'None')]
    [string] $Links = 'All',

    [ValidateRange(0, 3650)]
    [int] $RedirectMaxAge = 30,

    [ValidateRange(0.1, 20)]
    [double] $RequestsPerSecond = 4,

    [switch] $NoFetch
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
foreach ($helper in Get-ChildItem -Path (Join-Path $PSScriptRoot 'helpers') -Filter '*.ps1') { . $helper.FullName }

$script:LearnOrigin = 'https://learn.microsoft.com'
$script:UserAgent = 'Maester-step-tooling/1.0 (+https://github.com/maester365/maester)'
$script:LearnClient = $null
$script:LearnClock = $null

function Sync-MtLearnMirrorClone {
    <#
    .SYNOPSIS
    Clones a mirror into the cache folder, or brings an existing clone up to date. Returns the clone's folder, or
    nothing when -NoFetch is set and there is no clone.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory)] [string] $Name,
        [Parameter(Mandatory)] [string] $Owner,
        [Parameter(Mandatory)] [string] $MirrorPath,
        [switch] $NoFetch
    )

    $folder = Join-Path $MirrorPath $Name
    if (-not (Test-Path -LiteralPath (Join-Path $folder '.git'))) {
        if ($NoFetch) {
            Write-Warning "$Name has not been cloned yet, so it is left out. Run without -NoFetch to clone it."
            return
        }
        # Blobless: the whole history, but only the current version of each file. Older versions are fetched
        # when a script asks for one.
        $null = Invoke-MtGit -Path $MirrorPath -Arguments 'clone', '--quiet', '--filter=blob:none', '--single-branch', '--no-tags',
        "https://github.com/$Owner/$Name.git", $Name
        return $folder
    }
    if (-not $NoFetch) {
        $null = Invoke-MtGit -Path $folder -Arguments 'fetch', '--quiet', '--filter=blob:none', '--no-tags', 'origin'
        # The clone belongs to the cache, so it follows the mirror exactly.
        $null = Invoke-MtGit -Path $folder -Arguments 'reset', '--quiet', '--hard', '@{upstream}'
    }
    $folder
}

function Get-MtLearnMirrorPage {
    <#
    .SYNOPSIS
    Reads a mirror's configuration and the pages it holds: Key, Path and, for a URL that Learn redirects, Target.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Path
    )

    $config = @{}
    $configFile = Join-Path $Path 'learn-mirror.config.json'
    if (Test-Path -LiteralPath $configFile) { $config = Get-Content -LiteralPath $configFile -Raw | ConvertFrom-Json -AsHashtable }

    $tracked = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
    foreach ($file in Invoke-MtGit -Path $Path -Arguments '-c', 'core.quotePath=false', 'ls-files') { $null = $tracked.Add($file) }

    $pages = [System.Collections.Generic.List[object]]::new()
    $stateFile = Join-Path $Path '.learn-mirror/state.json'
    if (Test-Path -LiteralPath $stateFile) {
        $state = (Get-Content -LiteralPath $stateFile -Raw | ConvertFrom-Json -AsHashtable)['pages']
        foreach ($entry in $state.GetEnumerator()) {
            $key = ConvertTo-MtLearnKey $entry.Key
            if ([string]::IsNullOrEmpty($key)) { continue }
            # An alias is another URL that serves the same page. Its file is the one its original URL was written to.
            $page = $entry.Value
            for ($hop = 0; $hop -lt 5 -and -not $page['path'] -and $page['aliasOf'] -and $state.ContainsKey($page['aliasOf']); $hop++) {
                $page = $state[$page['aliasOf']]
            }
            $file = $page['path']
            if (-not $file -or -not $tracked.Contains($file)) { continue }
            $target = if ($entry.Value['redirectedTo']) { ConvertTo-MtLearnKey $entry.Value['redirectedTo'] } else { $null }
            $pages.Add([pscustomobject]@{ Key = $key; Path = $file; Target = if ($target -and $target -ne $key) { $target } else { $null } })
        }
    } else {
        Write-Warning "$(Split-Path $Path -Leaf) has no .learn-mirror/state.json. Indexing it from each page's canonicalUrl."
        foreach ($file in $tracked | Where-Object { $_ -like '*.md' -and $_ -notlike '.*' }) {
            $head = Get-Content -LiteralPath (Join-Path $Path $file) -TotalCount 80
            $canonical = $head | Where-Object { $_ -match '^canonicalUrl:\s*(\S+)' } | Select-Object -First 1
            if (-not $canonical) { continue }
            $key = ConvertTo-MtLearnKey (($canonical -replace '^canonicalUrl:\s*', '').Trim())
            if ($key) { $pages.Add([pscustomobject]@{ Key = $key; Path = $file; Target = $null }) }
        }
    }

    [pscustomobject]@{
        Include = $config['include']
        Exclude = @($config['exclude'] | Where-Object { $_ })
        Pages   = $pages
    }
}

function Send-MtLearnRequest {
    <#
    .SYNOPSIS
    Sends one GET to Learn without following redirects and returns the status, the Location header and any
    Retry-After, without reading the page.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [string] $Uri
    )

    if (-not $script:LearnClient) {
        $handler = [System.Net.Http.HttpClientHandler]::new()
        $handler.AllowAutoRedirect = $false
        $script:LearnClient = [System.Net.Http.HttpClient]::new($handler)
        $script:LearnClient.Timeout = [TimeSpan]::FromSeconds(30)
    }
    $request = [System.Net.Http.HttpRequestMessage]::new([System.Net.Http.HttpMethod]::Get, $Uri)
    # Learn applies its redirects to Markdown requests as it does to pages, and learn-mirror crawls this way.
    $null = $request.Headers.TryAddWithoutValidation('Accept', 'text/markdown')
    $null = $request.Headers.TryAddWithoutValidation('User-Agent', $script:UserAgent)
    try {
        $response = $script:LearnClient.SendAsync($request, [System.Net.Http.HttpCompletionOption]::ResponseHeadersRead).GetAwaiter().GetResult()
        $retryAfter = $null
        if ($response.Headers.RetryAfter -and $null -ne $response.Headers.RetryAfter.Delta) { $retryAfter = [int] $response.Headers.RetryAfter.Delta.TotalSeconds }
        [pscustomobject]@{
            Status     = [int] $response.StatusCode
            Location   = if ($response.Headers.Location) { $response.Headers.Location.OriginalString } else { $null }
            RetryAfter = $retryAfter
        }
        $response.Dispose()
    } finally {
        $request.Dispose()
    }
}

function Resolve-MtLearnRedirect {
    <#
    .SYNOPSIS
    Asks Learn where a page key goes, one hop at a time. Returns the answer to cache (Status Redirect, Page, Missing
    or External, To, Hops and Checked), or nothing when Learn could not be asked.
    #>
    [CmdletBinding()]
    [OutputType([System.Collections.Specialized.OrderedDictionary])]
    param(
        [Parameter(Mandatory)] [string] $Key,
        [double] $RequestsPerSecond = 4,
        [int] $MaxHops = 8
    )

    $uri = "$script:LearnOrigin/en-us/$Key"
    $hops = 0
    $retries = 0
    $answer = $null
    while ($true) {
        # Space the requests out.
        if (-not $script:LearnClock) { $script:LearnClock = [System.Diagnostics.Stopwatch]::new() }
        $wait = (1000 / $RequestsPerSecond) - $script:LearnClock.Elapsed.TotalMilliseconds
        if ($script:LearnClock.IsRunning -and $wait -gt 0) { Start-Sleep -Milliseconds ([int][math]::Ceiling($wait)) }
        $script:LearnClock.Restart()

        try {
            $response = Send-MtLearnRequest -Uri $uri
        } catch {
            Write-Warning "Could not ask Learn about ${Key}: $($_.Exception.Message)"
            return
        }

        if ($response.Status -in 429, 503) {
            if (++$retries -gt 3) { Write-Warning "Learn kept throttling the lookup of $Key. It is left unresolved."; return }
            $delay = if ($response.RetryAfter) { [math]::Min($response.RetryAfter, 120) } else { 15 * $retries }
            Start-Sleep -Seconds $delay
            continue
        }
        if ($response.Status -ge 200 -and $response.Status -lt 300) {
            $final = ConvertTo-MtLearnKey $uri
            $answer = [ordered]@{ Status = if ($final -ne $Key) { 'Redirect' } else { 'Page' }; To = $final; Hops = $hops }
            break
        }
        if ($response.Status -in 404, 410) {
            $answer = [ordered]@{ Status = 'Missing'; To = ConvertTo-MtLearnKey $uri; Hops = $hops }
            break
        }
        if ($response.Status -in 301, 302, 303, 307, 308 -and $response.Location) {
            $next = [System.Uri]::new([System.Uri]::new($uri), $response.Location).AbsoluteUri
            if ($null -eq (ConvertTo-MtLearnKey $next)) {
                $answer = [ordered]@{ Status = 'External'; To = $next; Hops = $hops + 1 }
                break
            }
            if (++$hops -gt $MaxHops) { Write-Warning "$Key redirects more than $MaxHops times. It is left unresolved."; return }
            $uri = $next
            continue
        }
        Write-Warning "Learn answered $($response.Status) for $Key. It is left unresolved."
        return
    }
    $answer['Checked'] = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
    $answer
}

function Select-MtLearnLookup {
    <#
    .SYNOPSIS
    Returns the linked pages to ask Learn about: those no mirror has under their key, with no cached answer or one
    older than -MaxAge days.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)] [AllowEmptyCollection()] [object[]] $Link,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Pages,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Redirects,
        [int] $MaxAge = 30,
        [datetime] $Now = [datetime]::UtcNow
    )

    $cutoff = $Now.ToUniversalTime().AddDays(-$MaxAge)
    # A generic dictionary has ContainsKey; an ordered dictionary has only Contains.
    $has = { param($dictionary, $key) if ($dictionary.PSObject.Methods['ContainsKey']) { $dictionary.ContainsKey($key) } else { $dictionary.Contains($key) } }
    foreach ($item in $Link) {
        if (& $has $Pages $item.Key) { continue }
        if (-not (& $has $Redirects $item.Key)) { $item; continue }
        # ConvertFrom-Json may already have read the timestamp as a date.
        $checked = $Redirects[$item.Key]['Checked']
        if ($checked -isnot [datetime]) {
            $parsed = [datetime]::MinValue
            $style = [System.Globalization.DateTimeStyles]::AdjustToUniversal -bor [System.Globalization.DateTimeStyles]::AssumeUniversal
            if (-not [datetime]::TryParse([string] $checked, [System.Globalization.CultureInfo]::InvariantCulture, $style, [ref] $parsed)) { $item; continue }
            $checked = $parsed
        }
        if ($MaxAge -eq 0 -or $checked.ToUniversalTime() -lt $cutoff) { $item }
    }
}

function Save-MtLearnRedirect {
    <#
    .SYNOPSIS
    Writes the redirect answers to redirects.json, sorted by key.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Path,
        [Parameter(Mandatory)] [System.Collections.IDictionary] $Redirects
    )

    $sorted = [ordered]@{}
    foreach ($key in @($Redirects.Keys) | Sort-Object) { $sorted[$key] = $Redirects[$key] }
    [ordered]@{ Version = 1; Redirects = $sorted } | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $Path -Encoding utf8NoBOM
}

# Lets the unit tests dot-source the functions above without running the script.
if ($MyInvocation.InvocationName -eq '.') { return }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) { throw 'git is required.' }
$mirrorRoot = Join-Path $CachePath 'mirrors'
$null = New-Item -ItemType Directory -Path $mirrorRoot -Force
$CachePath = (Resolve-Path -LiteralPath $CachePath).Path
$mirrorRoot = Join-Path $CachePath 'mirrors'

try {
    # 1. The mirrors and their pages.
    $pages = [System.Collections.Generic.SortedDictionary[string, object]]::new([System.StringComparer]::OrdinalIgnoreCase)
    $mirrorInfo = [ordered]@{}
    foreach ($name in $Mirror) {
        Write-Host "$(if ($NoFetch) { 'Reading' } else { 'Updating' }) $Owner/$name"
        $folder = Sync-MtLearnMirrorClone -Name $name -Owner $Owner -MirrorPath $mirrorRoot -NoFetch:$NoFetch
        if (-not $folder) { continue }
        $content = Get-MtLearnMirrorPage -Path $folder
        $added = 0
        foreach ($page in $content.Pages) {
            if ($pages.ContainsKey($page.Key)) {
                if ($pages[$page.Key].Mirror -ne $name) { Write-Verbose "$($page.Key) is in both $($pages[$page.Key].Mirror) and $name. The first is used." }
                continue
            }
            $entry = [ordered]@{ Mirror = $name; Path = $page.Path }
            if ($page.Target) { $entry['Target'] = $page.Target }
            $pages[$page.Key] = $entry
            $added++
        }
        $mirrorInfo[$name] = [ordered]@{
            Repository = "$Owner/$name"
            Commit     = (Invoke-MtGit -Path $folder -Arguments 'rev-parse', 'HEAD') | Select-Object -First 1
            CommitDate = (Invoke-MtGit -Path $folder -Arguments 'log', '-1', '--format=%cI') | Select-Object -First 1
            Pages      = $added
            Include    = $content.Include
            Exclude    = $content.Exclude
        }
    }
    $index = [ordered]@{
        Version   = 1
        Generated = [datetime]::UtcNow.ToString('yyyy-MM-ddTHH:mm:ssZ', [System.Globalization.CultureInfo]::InvariantCulture)
        Owner     = $Owner
        Mirrors   = $mirrorInfo
        Pages     = $pages
    }
    $index | ConvertTo-Json -Depth 5 -Compress | Set-Content -LiteralPath (Join-Path $CachePath 'index.json') -Encoding utf8NoBOM
    Write-Host "Indexed $($pages.Count) pages from $($mirrorInfo.Count) mirrors."

    # 2. Linked URLs that no mirror has under that key: ask Learn where they go.
    $redirectFile = Join-Path $CachePath 'redirects.json'
    $redirects = [ordered]@{}
    if (Test-Path -LiteralPath $redirectFile) {
        $saved = Get-Content -LiteralPath $redirectFile -Raw | ConvertFrom-Json -AsHashtable -Depth 10
        if ($saved -and $saved['Redirects']) { foreach ($entry in $saved['Redirects'].GetEnumerator()) { $redirects[$entry.Key] = $entry.Value } }
    }
    $linked = @()
    if ($Links -ne 'None') {
        $linked = @(Get-MtLearnLink -Root $Root -Links $Links)
        $todo = @(Select-MtLearnLookup -Link $linked -Pages $pages -Redirects $redirects -MaxAge $RedirectMaxAge)
        if ($todo.Count -gt 0) { Write-Host "Asking Learn about $($todo.Count) linked URLs that no mirror has under that key." }
        $done = 0
        foreach ($link in $todo) {
            $answer = Resolve-MtLearnRedirect -Key $link.Key -RequestsPerSecond $RequestsPerSecond
            if ($answer) { $redirects[$link.Key] = $answer }
            if ((++$done % 25) -eq 0) {
                Save-MtLearnRedirect -Path $redirectFile -Redirects $redirects
                Write-Host "  $done of $($todo.Count)"
            }
        }
        Save-MtLearnRedirect -Path $redirectFile -Redirects $redirects
    }

    # 3. Summary.
    $readIndex = Read-MtLearnIndex -CachePath $CachePath
    $resolved = foreach ($link in $linked) { [pscustomobject]@{ Link = $link; Page = Resolve-MtLearnPage -Index $readIndex -Url $link.Url } }
    $byStatus = [ordered]@{}
    foreach ($status in 'Mirrored', 'Redirected', 'NotInMirror', 'NotMirrored', 'Missing', 'External', 'Unresolved') {
        $byStatus[$status] = @($resolved | Where-Object { $_.Page.Status -eq $status }).Count
    }
    if ($linked.Count -gt 0) {
        Write-Host "Linked pages: $($linked.Count). $(($byStatus.GetEnumerator() | Where-Object Value | ForEach-Object { "$($_.Key) $($_.Value)" }) -join ', ')."
        $guidePages = @($resolved | Where-Object { $_.Page.Mirror -in 'intune-docs-mirror', 'defender-docs-mirror' -and ($_.Link.From | Where-Object Kind -EQ 'Guide') })
        if ($guidePages.Count -gt 0) {
            $redirected = @($guidePages | Where-Object { $_.Page.Status -eq 'Redirected' })
            $count = { param($items) @($items | ForEach-Object { $_.Link.From | Where-Object Kind -EQ 'Guide' }).Count }
            Write-Host "Intune and Defender pages linked from check guides: $($redirected.Count) of $($guidePages.Count) are linked by a URL that Learn redirects ($(& $count $redirected) of $(& $count $guidePages) links)."
        }
        foreach ($item in $resolved | Where-Object { $_.Page.Status -in 'Missing', 'NotInMirror', 'Unresolved' }) {
            $where = ($item.Link.From | Select-Object -First 3 | ForEach-Object { if ($_.Line) { "$($_.File):$($_.Line)" } else { "$($_.File) ($($_.Id))" } }) -join ', '
            Write-Host "  $($item.Page.Status): $($item.Link.Url) ($where)"
        }
    }

    [pscustomobject]@{
        CachePath = $CachePath
        Mirrors   = @($mirrorInfo.Keys)
        Pages     = $pages.Count
        Links     = $linked.Count
        Status    = [pscustomobject]$byStatus
    }
} finally {
    if ($script:LearnClient) { $script:LearnClient.Dispose(); $script:LearnClient = $null }
}
