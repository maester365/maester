function Invoke-MtGitHubRequest {
    <#
    .SYNOPSIS
    Internal: Authenticated read-only GET request to GitHub REST API with caching and pagination.

    .DESCRIPTION
    Uses Invoke-WebRequest for PowerShell 5.1 compatibility (Invoke-RestMethod
    -ResponseHeadersVariable is PowerShell 7+ only). Provides per-session caching,
    explicit opt-in pagination, and rate-limit detection.

    Cache key: ApiVersion|absoluteUri (cleared on reconnect and by Clear-ModuleVariable).
    Rate-limit detection: checks x-ratelimit-remaining in both success and error responses.

    .PARAMETER RelativeUri
    Path relative to ApiBaseUri. URL-encode path segments with [Uri]::EscapeDataString.

    .PARAMETER Paginate
    Follows Link header rel="next" and appends per_page=100. Use for list endpoints only.

    .PARAMETER DisableCache
    Bypasses session cache; makes a live API call.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [string] $RelativeUri,
        [switch] $Paginate,
        [switch] $DisableCache
    )

    if ($null -eq $__MtSession.GitHubConnection -or
        $__MtSession.GitHubConnection.Connected -ne $true) {
        throw "Not connected to GitHub. Call Connect-MtGitHub first."
    }

    $baseUri = $__MtSession.GitHubConnection.ApiBaseUri
    $version = $__MtSession.GitHubConnection.ApiVersion
    $headers = $__MtSession.GitHubAuthHeader

    $absUri = "$baseUri/$($RelativeUri.TrimStart('/'))"
    if ($Paginate -and $absUri -notmatch '[?&]per_page=') {
        $sep = if ($absUri -match '\?') { '&' } else { '?' }
        $absUri = "${absUri}${sep}per_page=100"
    }

    $cacheKey = "$version|$absUri"
    if (-not $DisableCache -and $__MtSession.GitHubCache.ContainsKey($cacheKey)) {
        Write-Verbose "GitHub cache hit: $absUri"
        return $__MtSession.GitHubCache[$cacheKey]
    }

    function Invoke-Page ([string]$Uri) {
        try {
            $wr = Invoke-WebRequest -Uri $Uri -Headers $headers -Method GET -UseBasicParsing -ErrorAction Stop

            $body = if (-not [string]::IsNullOrWhiteSpace($wr.Content)) {
                $wr.Content | ConvertFrom-Json
            } else {
                $null
            }

            # Rate-limit warning on successful response — do NOT throw; the response body is valid.
            $remaining = Get-MtGitHubResponseHeaderValue -Headers $wr.Headers -Name 'x-ratelimit-remaining'
            if ($null -ne $remaining -and [int]$remaining -eq 0) {
                $reset = Get-MtGitHubResponseHeaderValue -Headers $wr.Headers -Name 'x-ratelimit-reset'
                $resetTime = if ($reset) { [DateTimeOffset]::FromUnixTimeSeconds([long]$reset).LocalDateTime } else { 'unknown' }
                Write-Verbose "GitHub API rate limit remaining is 0 after this successful response. Resets at: $resetTime"
            }

            $linkHeader = Get-MtGitHubResponseHeaderValue -Headers $wr.Headers -Name 'Link'
            return [PSCustomObject]@{ Body = $body; Link = $linkHeader }
        } catch {
            $rateLimitMessage = Get-MtGitHubRateLimitMessage -ErrorRecord $_
            if ($rateLimitMessage) { throw $rateLimitMessage }
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

    $first = Invoke-Page $absUri

    if (-not $Paginate) {
        $result = $first.Body
    } else {
        $all = [System.Collections.Generic.List[object]]::new()
        $all.AddRange(@($first.Body))
        $next = Get-NextLink $first.Link
        while ($null -ne $next) {
            if (-not (Test-NextLinkSameOrigin -NextUri $next -BaseUri $baseUri)) {
                throw "GitHub pagination refused: next link '$next' is outside the configured ApiBaseUri '$baseUri'."
            }
            $page = Invoke-Page $next
            $all.AddRange(@($page.Body))
            $next = Get-NextLink $page.Link
        }
        $result = $all.ToArray()
    }

    if (-not $DisableCache) { $__MtSession.GitHubCache[$cacheKey] = $result }
    return $result
}
