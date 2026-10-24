function Invoke-MtGitHubRateLimitGuard {
    <#
    .SYNOPSIS
    Internal: Stops affected outbound GitHub requests until the observed server deadline.
    .DESCRIPTION
    Call without response parameters immediately before transport, including each page. With response
    parameters, records a limit and throws only for an error response. Successful exhausted responses
    remain usable. Cache reads are allowed; DisableCache never bypasses this guard.
    State belongs to the authenticated connection and API authority and survives per-run cache clearing.
    Reconnecting creates a new connection. No sleeping or automatic retry is performed.
    See https://docs.github.com/en/rest/using-the-rest-api/best-practices-for-using-the-rest-api#handle-rate-limit-errors-appropriately.
    #>
    [CmdletBinding()]
    param(
        [ValidateSet('REST', 'GraphQL')] [string] $Api = 'REST',
        [object] $Connection = $__MtSession.GitHubConnection,
        [object] $ErrorRecord,
        [AllowNull()] [object] $Headers,
        [int] $StatusCode = 200,
        [switch] $GraphQLRateLimited,
        [string] $Message
    )
    if (-not [object]::ReferenceEquals($__MtSession.GitHubRateLimits.Connection, $Connection)) {
        $__MtSession.GitHubRateLimits = @{ Connection = $Connection; Limits = @{} }
    }
    $authority = ([uri]$Connection.ApiBaseUri).GetLeftPart([UriPartial]::Authority)
    $limits = $__MtSession.GitHubRateLimits.Limits
    $observing = $PSBoundParameters.ContainsKey('Headers') -or $ErrorRecord -or $GraphQLRateLimited
    if ($observing) {
        $limit = Get-MtGitHubRateLimit -Api $Api -ErrorRecord $ErrorRecord -Headers $Headers -StatusCode $StatusCode -GraphQLRateLimited:$GraphQLRateLimited -Message $Message
        if (-not $limit) { return }
        $key = "$authority|$($limit.Scope)"
        if (-not $limits.ContainsKey($key) -or $limit.ResumeUtc -gt $limits[$key].ResumeUtc) { $limits[$key] = $limit }
        if (-not $ErrorRecord -and -not $GraphQLRateLimited -and $StatusCode -eq 200) {
            $resetText = if ($limit.ResetUtc) { $limit.ResetUtc.LocalDateTime } else { 'unknown' }
            Write-Verbose "GitHub API rate limit remaining is 0 after this successful response. Resets at: $resetText"
            return
        }
    } else {
        $limit = @('All', $Api | ForEach-Object { $limits["$authority|$_"] } | Where-Object { $_ -and $_.ResumeUtc -ge [DateTimeOffset]::UtcNow } | Sort-Object ResumeUtc -Descending | Select-Object -First 1)[0]
        if (-not $limit) { return }
    }
    $diagnostic = if ($Api -eq 'GraphQL') { 'GitHub GraphQL execution failed. ' + $limit.Message } else { $limit.Message }
    $exception = [System.InvalidOperationException]::new($diagnostic)
    $exception.Data['GitHubRateLimit'] = $limit
    throw $exception
}
