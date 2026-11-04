function Get-MtGitHubRateLimit {
    <#
    .SYNOPSIS
    Internal: Classifies GitHub primary/secondary limits without parsing Maester diagnostic text.
    .DESCRIPTION
    Returns a separate record for each observed limit. Primary REST and GraphQL quotas are separate;
    secondary limits can be shared across both APIs, with their own deadline.
    Uses response headers, documented API error messages and GraphQL RATE_LIMITED errors.
    An unknown primary reset requires a new connection; no retry time is invented for it.
    #>
    [CmdletBinding()]
    param(
        [object] $ErrorRecord,
        [AllowNull()] [object] $Headers,
        [int] $StatusCode = 200,
        [ValidateSet('REST', 'GraphQL')] [string] $Api = 'REST',
        [switch] $GraphQLRateLimited,
        [string] $Message
    )
    if ($ErrorRecord) {
        if ($ErrorRecord.Exception.Data['GitHubRateLimits']) { return $ErrorRecord.Exception.Data['GitHubRateLimits'] }
        if ($ErrorRecord.Exception.Data['GitHubRateLimit']) { return $ErrorRecord.Exception.Data['GitHubRateLimit'] }
        $StatusCode = Get-MtGitHubErrorStatusCode -ErrorRecord $ErrorRecord
        if ($StatusCode -notin 403, 429) { return $null }
        $Headers = $ErrorRecord.Exception.Response.Headers
        $Message = Get-MtGitHubErrorMessage -ErrorRecord $ErrorRecord
    }
    $remaining = Get-MtGitHubResponseHeaderValue -Headers $Headers -Name 'x-ratelimit-remaining'
    $remainingValue = 0
    $primary = $null -ne $remaining -and [int]::TryParse([string]$remaining, [ref]$remainingValue) -and $remainingValue -eq 0
    $retryAfter = Get-MtGitHubResponseHeaderValue -Headers $Headers -Name 'retry-after'
    $secondary = $Message -match '(?i)secondary\s+rate\s+limit|abuse\s+detection' -or (($StatusCode -in 403, 429 -or $GraphQLRateLimited) -and $null -ne $retryAfter)
    if (-not $primary -and -not $secondary -and $StatusCode -ne 429 -and -not $GraphQLRateLimited) { return $null }
    if ($StatusCode -notin 200, 403, 429) { return $null }

    $now = [DateTimeOffset]::UtcNow
    $reset = Get-MtGitHubResponseHeaderValue -Headers $Headers -Name 'x-ratelimit-reset'
    $resetSeconds = 0L
    $resetUtc = $null
    if ($null -ne $reset -and [long]::TryParse([string]$reset, [ref]$resetSeconds)) {
        try { $resetUtc = [DateTimeOffset]::FromUnixTimeSeconds($resetSeconds) } catch { Write-Debug 'GitHub returned an out-of-range reset epoch.' }
    }
    $retrySeconds = 0L
    $retryUtc = $null
    if ($null -ne $retryAfter -and [long]::TryParse([string]$retryAfter, [ref]$retrySeconds) -and $retrySeconds -ge 0) {
        try { $retryUtc = $now.AddSeconds($retrySeconds) } catch { Write-Debug 'GitHub returned an out-of-range retry interval.' }
    }
    $resource = Get-MtGitHubResponseHeaderValue -Headers $Headers -Name 'x-ratelimit-resource'
    if ($primary) {
        # An unknown reset blocks only the exhausted API, not the other primary quota.
        $resumeUtc = if ($null -eq $resetUtc -or $resetUtc -ge [DateTimeOffset]::MaxValue.AddSeconds(-1)) { [DateTimeOffset]::MaxValue }
        else { $resetUtc.AddSeconds(1) }
        $resetText = if ($resetUtc) { $resetUtc.LocalDateTime } else { 'unknown' }
        [pscustomobject]@{
            Kind = 'Primary'; Scope = $Api; HttpStatus = $StatusCode; Resource = $resource
            RetryAfterSeconds = $null; ResetUtc = $resetUtc; ResumeUtc = $resumeUtc
            Message = "GitHub API rate limit encountered (HTTP $StatusCode). Resets at: $resetText"
        }
    }
    if ($secondary -or -not $primary) {
        # A simultaneous primary reset must neither extend nor shorten the shared cooldown.
        $resumeUtc = if ($retryUtc) { $retryUtc } else { $now.AddSeconds(60) }
        $diagnostic = if ($retryUtc) { "GitHub secondary rate limit encountered (HTTP $StatusCode). Retry after: ${retrySeconds}s" }
        else { "GitHub secondary rate limit encountered (HTTP $StatusCode). Retry after at least 60s." }
        [pscustomobject]@{
            Kind = 'Secondary'; Scope = 'All'; HttpStatus = $StatusCode; Resource = $resource
            RetryAfterSeconds = $(if ($retryUtc) { $retrySeconds } else { $null })
            ResetUtc = $null; ResumeUtc = $resumeUtc; Message = $diagnostic
        }
    }
}
