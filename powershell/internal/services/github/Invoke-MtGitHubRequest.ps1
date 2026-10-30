function Invoke-MtGitHubRequest {
    <#
    .SYNOPSIS
    Internal: Authenticated read-only GET request to GitHub REST API with caching and pagination.

    .DESCRIPTION
    Uses Invoke-WebRequest for PowerShell 5.1 compatibility (Invoke-RestMethod
    -ResponseHeadersVariable is PowerShell 7+ only). Provides per-session caching,
    explicit opt-in pagination, and connection-scoped rate-limit protection.

    Cache key: ApiVersion|absoluteUri (cleared on reconnect and by Clear-ModuleVariable).
    Rate-limit protection: observes primary exhaustion and shared secondary limits on every page.

    .PARAMETER RelativeUri
    Path relative to ApiBaseUri. URL-encode path segments with [Uri]::EscapeDataString.

    .PARAMETER Paginate
    Follows Link header rel="next" and appends per_page=100. Use for list endpoints only.

    .PARAMETER ApiVersion
    Optional per-call REST version. Does not change the connection default.

    .PARAMETER IncludeMetadata
    Returns evidence timestamps and pre-aggregation collection integrity. Legacy body callers are unchanged.

    .PARAMETER DisableCache
    Bypasses session cache. Active rate-limit protection still applies.

    .PARAMETER MaxPages
    Optional page bound for metadata pagination. Capped evidence is incomplete and is not cached.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $RelativeUri,
        [switch] $Paginate,
        [switch] $DisableCache,
        [ValidatePattern('^\d{4}-\d{2}-\d{2}$')]
        [string] $ApiVersion,
        [switch] $IncludeMetadata,
        [ValidateRange(1, 100)] [int] $MaxPages
    )

    if ($PSBoundParameters.ContainsKey('MaxPages') -and (-not $IncludeMetadata -or -not $Paginate)) {
        throw 'MaxPages requires IncludeMetadata and Paginate.'
    }

    if ($null -eq $__MtSession.GitHubConnection -or
        $__MtSession.GitHubConnection.Connected -ne $true) {
        throw "Not connected to GitHub. Call Connect-MtGitHub first."
    }

    $baseUri = $__MtSession.GitHubConnection.ApiBaseUri
    $version = if ($ApiVersion) { $ApiVersion } else { $__MtSession.GitHubConnection.ApiVersion }
    $headers = $__MtSession.GitHubAuthHeader
    if ($ApiVersion) {
        $headers = @{} + $__MtSession.GitHubAuthHeader
        $headers['X-GitHub-Api-Version'] = $ApiVersion
    }

    $absUri = "$baseUri/$($RelativeUri.TrimStart('/'))"
    if ($Paginate -and $absUri -notmatch '[?&]per_page=') {
        $sep = if ($absUri -match '\?') { '&' } else { '?' }
        $absUri = "${absUri}${sep}per_page=100"
    }

    $cacheKey = if ($IncludeMetadata) {
        "Metadata|GET|$version|$absUri|Paginate=$($Paginate.IsPresent)"
    } else { Get-MtGitHubCacheKey -ApiVersion $version -AbsoluteUri $absUri }
    if ($MaxPages) { $cacheKey += "|MaxPages=$MaxPages" }
    if ($IncludeMetadata -and -not $DisableCache -and $__MtSession.GitHubCache.ContainsKey($cacheKey)) {
        $cached = $__MtSession.GitHubCache[$cacheKey]
        if ($cached.CompletedUtc -isnot [DateTimeOffset] -or ([DateTimeOffset]::UtcNow - $cached.CompletedUtc).TotalMinutes -ge 5) {
            $__MtSession.GitHubCache.Remove($cacheKey)
        }
    }
    if (-not $DisableCache -and $__MtSession.GitHubCache.ContainsKey($cacheKey)) {
        Write-Verbose "GitHub cache hit: $absUri"
        return $__MtSession.GitHubCache[$cacheKey]
    }

    function Invoke-Page ([string]$Uri) {
        Invoke-MtGitHubRateLimitGuard -Api REST
        try {
            $wr = Invoke-WebRequest -Uri $Uri -Headers $headers -Method GET -UseBasicParsing -ErrorAction Stop

            Invoke-MtGitHubRateLimitGuard -Api REST -Headers $wr.Headers

            $kind = 'Empty'
            $limited = $false
            $body = if ($IncludeMetadata) {
                if (-not [string]::IsNullOrWhiteSpace($wr.Content)) {
                    # Preserve array shape and null members before any collection aggregation.
                    $parsed = ConvertFrom-Json -InputObject $wr.Content -NoEnumerate -ErrorAction Stop
                    $kind = if ($null -eq $parsed) { 'Null' } elseif ($parsed -is [array]) { 'Array' } elseif ($null -ne $parsed -and $parsed.GetType() -eq [System.Management.Automation.PSCustomObject]) { 'Object' } else { 'Scalar' }
                    $parsed
                }
            } elseif (-not [string]::IsNullOrWhiteSpace($wr.Content)) {
                # ConvertFrom-Json '[]' yields $null because it enumerates the (empty)
                # array, so pagination can't distinguish "no items" from "one null item"
                # without short-circuiting the empty-array case here.
                if ($wr.Content.Trim() -eq '[]') {
                    ,@()
                } else {
                    $wr.Content | ConvertFrom-Json
                }
            } else {
                $null
            }

            if ($IncludeMetadata -and $kind -eq 'Array') { $body = $parsed }
            if ($IncludeMetadata) {
                $sso = Get-MtGitHubResponseHeaderValue -Headers $wr.Headers -Name 'X-GitHub-SSO'
                $limited = $null -ne $sso -and $sso -match '(?i)partial-results|required'
            }

            $linkHeader = Get-MtGitHubResponseHeaderValue -Headers $wr.Headers -Name 'Link'
            return [PSCustomObject]@{ Body = $body; Link = $linkHeader; ContentKind = $kind; AccessLimited = $limited }
        } catch {
            Invoke-MtGitHubRateLimitGuard -Api REST -ErrorRecord $_
            throw
        }
    }

    function Get-NextLink ([string]$Link) {
        if ([string]::IsNullOrEmpty($Link)) { return $null }
        $m = [regex]::Match($Link, '<([^>]+)>;\s*rel="next"')
        if ($m.Success) { return $m.Groups[1].Value }
        return $null
    }

    # Refuse to follow a Link rel="next" that points outside the configured ApiBaseUri.
    # A malicious or buggy upstream that injects a foreign URL would otherwise receive
    # the Authorization header on a cross-origin request. Compare scheme + host + port
    # + base path prefix so GHE bases like https://host/api/v3 are honored.
    function Test-NextLinkSameOrigin ([string]$NextUri, [string]$BaseUri) {
        $baseParsed = $null
        $nextParsed = $null
        if (-not [uri]::TryCreate($BaseUri, [UriKind]::Absolute, [ref]$baseParsed)) { return $false }
        if (-not [uri]::TryCreate($NextUri, [UriKind]::Absolute, [ref]$nextParsed)) { return $false }
        if ($baseParsed.Scheme -ne $nextParsed.Scheme) { return $false }
        if (-not [string]::Equals($baseParsed.Host, $nextParsed.Host, [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
        if ($baseParsed.Port -ne $nextParsed.Port) { return $false }
        $basePath = $baseParsed.AbsolutePath.TrimEnd('/')
        $nextPath = $nextParsed.AbsolutePath
        if ([string]::IsNullOrEmpty($basePath)) { return $true }
        return $nextPath -eq $basePath -or $nextPath.StartsWith("$basePath/", [System.StringComparison]::Ordinal)
    }

    $started = [DateTimeOffset]::UtcNow
    $first = Invoke-Page $absUri

    if ($IncludeMetadata) {
        $items = [System.Collections.Generic.List[object]]::new()
        $issues = [System.Collections.Generic.List[string]]::new()
        $visited = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::Ordinal)
        $null = $visited.Add($absUri)
        $pageCount = 0
        $accessLimited = $false
        $page = $first
        do {
            $pageCount++
            if ($page.AccessLimited) { $accessLimited = $true }
            if ($Paginate) {
                if ($page.ContentKind -ne 'Array') {
                    $issues.Add("Page $pageCount is $($page.ContentKind), not a collection array.")
                } else {
                    $index = 0
                    foreach ($item in $page.Body) {
                        if (($null -eq $item -or $item.GetType() -ne [System.Management.Automation.PSCustomObject])) { $issues.Add("Page $pageCount item $index is not an object.") }
                        $items.Add($item)
                        $index++
                    }
                }
            } elseif ($page.ContentKind -eq 'Array') {
                $index = 0
                foreach ($item in $page.Body) {
                    if ($null -eq $item -or $item.GetType() -ne [System.Management.Automation.PSCustomObject]) { $issues.Add("Page $pageCount item $index is not an object.") }
                    $index++
                }
            } elseif ($page.ContentKind -ne 'Object') {
                $issues.Add("Response is $($page.ContentKind), not an object or array.")
            }
            $next = Get-NextLink $page.Link
            if (-not $Paginate -or $null -eq $next) { break }
            if ($MaxPages -and $pageCount -ge $MaxPages) {
                $issues.Add('Pagination page cap reached.')
                break
            }
            if (-not (Test-NextLinkSameOrigin -NextUri $next -BaseUri $baseUri)) { throw 'GitHub pagination refused a foreign next link.' }
            if (-not $visited.Add($next)) { throw 'GitHub pagination cycle detected.' }
            try { $page = Invoke-Page $next } catch {
                $_.Exception.Data['GitHubPartialResponse'] = [pscustomobject]@{
                    Data = $items.ToArray(); PageCount = $pageCount; PaginationComplete = $false
                    StartedUtc = $started; CompletedUtc = [DateTimeOffset]::UtcNow
                }
                throw
            }
        } while ($true)
        if ($accessLimited) { $issues.Add('GitHub reported limited authentication or partial SSO results.') }
        $result = [pscustomobject]@{
            Data = $(if ($Paginate) { $items.ToArray() } else { $first.Body })
            ContentKind = $first.ContentKind
            StartedUtc = $started
            CompletedUtc = [DateTimeOffset]::UtcNow
            PageCount = $pageCount
            TraversalMode = $(if ($Paginate) { 'AllPages' } else { 'SinglePage' })
            PaginationComplete = $Paginate.IsPresent -and $null -eq $next
            CollectionIntegrityValid = $issues.Count -eq 0
            AccessLimited = $accessLimited
            Issues = $issues.ToArray()
        }
        # Assignment expressions also enumerate singleton arrays; the envelope retains the exact array.
        if ($Paginate) { $result.Data = $items.ToArray() } else { $result.Data = $first.Body }
        if (-not $DisableCache -and $result.CollectionIntegrityValid -and (-not $Paginate -or $result.PaginationComplete)) { $__MtSession.GitHubCache[$cacheKey] = $result }
        return $result
    }

    if (-not $Paginate) {
        $result = $first.Body
    } else {
        $all = [System.Collections.Generic.List[object]]::new()
        # Filter $null per page so an empty-content or `[]` page does not contribute
        # spurious null items to the merged result.
        foreach ($item in @($first.Body)) {
            if ($null -ne $item) { $all.Add($item) }
        }
        $pageCount = 1
        $next = Get-NextLink $first.Link
        while ($null -ne $next) {
            if (-not (Test-NextLinkSameOrigin -NextUri $next -BaseUri $baseUri)) {
                throw "GitHub pagination refused: next link '$next' is outside the configured ApiBaseUri '$baseUri'."
            }
            try { $page = Invoke-Page $next } catch {
                $_.Exception.Data['GitHubPartialResponse'] = [pscustomobject]@{
                    Data = $all.ToArray(); PageCount = $pageCount; PaginationComplete = $false
                    StartedUtc = $started; CompletedUtc = [DateTimeOffset]::UtcNow
                }
                throw
            }
            $pageCount++
            foreach ($item in @($page.Body)) {
                if ($null -ne $item) { $all.Add($item) }
            }
            $next = Get-NextLink $page.Link
        }
        $result = $all.ToArray()
    }

    if (-not $DisableCache) { $__MtSession.GitHubCache[$cacheKey] = $result }
    return $result
}
