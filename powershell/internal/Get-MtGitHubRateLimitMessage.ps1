function Get-MtGitHubRateLimitMessage {
    <#
    .SYNOPSIS
    Internal: Returns a GitHub rate-limit message for an ErrorRecord, or $null when the
    error is not a rate-limit response.

    .DESCRIPTION
    Mirrors the rate-limit detection in Invoke-MtGitHubRequest so that bootstrap callers
    (Connect-MtGitHub) can distinguish HTTP 403/429 caused by rate limiting from
    permission, token, or org-access failures.

    Returns:
      - "GitHub API rate limit encountered (HTTP <code>). Resets at: <time>" when the
        response carries x-ratelimit-remaining = 0 (primary rate limit).
      - "GitHub secondary rate limit encountered (HTTP <code>). Retry after: <n>s" when
        the response carries retry-after (secondary rate limit / abuse detection).
      - "GitHub secondary rate limit encountered (HTTP <code>). Retry after at least 60s."
        when the response body indicates secondary-limit / abuse-detection wording but
        no retry-after header is present.
      - $null for any other error, including 403/429 without rate-limit headers.
    #>
    param(
        [Parameter(Mandatory)] $ErrorRecord
    )

    $code = Get-MtGitHubErrorStatusCode -ErrorRecord $ErrorRecord
    if ($code -notin 403, 429) { return $null }

    $response = $null
    try {
        if ($null -ne $ErrorRecord.Exception) { $response = $ErrorRecord.Exception.Response }
    } catch {
        Write-Debug "Get-MtGitHubRateLimitMessage: $($_.Exception.Message)"
    }
    if ($null -eq $response) { return $null }

    $headers = $null
    try { $headers = $response.Headers } catch {
        Write-Debug "Get-MtGitHubRateLimitMessage headers: $($_.Exception.Message)"
    }
    if ($null -eq $headers) { return $null }

    $remaining = Get-MtGitHubResponseHeaderValue -Headers $headers -Name 'x-ratelimit-remaining'
    $remainingValue = 0
    $remainingParsed = $null -ne $remaining -and [int]::TryParse([string]$remaining, [ref]$remainingValue)
    if ($remainingParsed -and $remainingValue -eq 0) {
        $reset = Get-MtGitHubResponseHeaderValue -Headers $headers -Name 'x-ratelimit-reset'
        $resetSeconds = 0L
        $resetTime = 'unknown'
        if ($null -ne $reset -and [long]::TryParse([string]$reset, [ref]$resetSeconds)) {
            try { $resetTime = [DateTimeOffset]::FromUnixTimeSeconds($resetSeconds).LocalDateTime } catch {
                Write-Debug "Get-MtGitHubRateLimitMessage reset conversion: $($_.Exception.Message)"
            }
        }
        return "GitHub API rate limit encountered (HTTP $code). Resets at: $resetTime"
    }

    $retryAfter = Get-MtGitHubResponseHeaderValue -Headers $headers -Name 'retry-after'
    if ($null -ne $retryAfter) {
        return "GitHub secondary rate limit encountered (HTTP $code). Retry after: ${retryAfter}s"
    }

    # Some secondary-limit responses omit retry-after entirely (e.g. older abuse-detection
    # responses, or responses where the proxy strips the header). Fall back to body wording -
    # GitHub's documented messages include phrases like "secondary rate limit" and
    # "abuse detection mechanism". When matched, recommend the 60-second minimum backoff
    # documented at https://docs.github.com/en/rest/using-the-rest-api/rate-limits-for-the-rest-api.
    $bodyMessage = Get-MtGitHubErrorMessage -ErrorRecord $ErrorRecord
    if (-not [string]::IsNullOrEmpty($bodyMessage) -and
        $bodyMessage -match '(?i)secondary\s+rate\s+limit|abuse\s+detection') {
        return "GitHub secondary rate limit encountered (HTTP $code). Retry after at least 60s."
    }

    return $null
}
