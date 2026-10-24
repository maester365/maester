function Invoke-MtGitHubGraphQLRequest {
    <#
    .SYNOPSIS
    Internal: Runs a static GitHub GraphQL read query with session-isolated evidence caching.
    .DESCRIPTION
    GraphQL is not versioned by X-GitHub-Api-Version. Error and partial responses are never cached.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] [string] $Query,
        [Parameter(Mandatory)] [hashtable] $Variables,
        [Parameter(Mandatory)] [string] $OperationName,
        [switch] $DisableCache
    )
    if (-not $__MtSession.GitHubConnection -or $__MtSession.GitHubConnection.Connected -ne $true) {
        throw 'Not connected to GitHub. Call Connect-MtGitHub first.'
    }
    if ($Query -notmatch '^\s*query\s' -or $Query -match '\bmutation\b') { throw 'Only static read queries are supported.' }
    $uri = "$($__MtSession.GitHubConnection.ApiBaseUri.TrimEnd('/'))/graphql"
    $payload = @{ query = $Query; variables = $Variables; operationName = $OperationName } | ConvertTo-Json -Depth 20 -Compress
    $digest = [Convert]::ToHexString([System.Security.Cryptography.SHA256]::HashData([Text.Encoding]::UTF8.GetBytes($payload)))
    $key = "GraphQL|$uri|$digest"
    if (-not $DisableCache -and $__MtSession.GitHubCache.ContainsKey($key)) {
        $cached = $__MtSession.GitHubCache[$key]
        if (([DateTimeOffset]::UtcNow - $cached.CompletedUtc).TotalMinutes -lt 5) { return $cached }
        $__MtSession.GitHubCache.Remove($key)
    }
    $headers = @{} + $__MtSession.GitHubAuthHeader
    $headers.Remove('X-GitHub-Api-Version')
    $started = [DateTimeOffset]::UtcNow
    $response = Invoke-WebRequest -Uri $uri -Method POST -Headers $headers -ContentType 'application/json' -Body $payload -ErrorAction Stop
    $parsed = ConvertFrom-Json -InputObject $response.Content -NoEnumerate -ErrorAction Stop
    $codes = [System.Collections.Generic.List[string]]::new()
    if (($null -ne $parsed -and $parsed.GetType() -eq [System.Management.Automation.PSCustomObject]) -and (Test-MtGitHubObjectProperty -InputObject $parsed -PropertyName errors)) {
        if ($parsed.errors -isnot [array]) { throw 'GitHub GraphQL error collection is unusable.' }
        foreach ($errorItem in $parsed.errors) {
            if ($null -eq $errorItem -or $errorItem.GetType() -ne [System.Management.Automation.PSCustomObject]) { throw 'GitHub GraphQL error collection is unusable.' }
            $code = if ($errorItem.type) { $errorItem.type } elseif ($errorItem.extensions.code) { $errorItem.extensions.code } else { 'UNKNOWN' }
            if ($code -cnotin 'FORBIDDEN', 'NOT_FOUND', 'INSUFFICIENT_SCOPES') { throw 'GitHub GraphQL execution failed; no configuration verdict was produced.' }
            $codes.Add($code)
        }
    }
    $data = $null
    if ($null -ne $parsed -and $parsed.GetType() -eq [System.Management.Automation.PSCustomObject] -and $null -ne $parsed.data -and $parsed.data.GetType() -eq [System.Management.Automation.PSCustomObject]) { $data = $parsed.data }
    $result = [pscustomobject]@{ Data = $data; Errors = $codes.ToArray(); StartedUtc = $started; CompletedUtc = [DateTimeOffset]::UtcNow }
    if (-not $DisableCache -and $codes.Count -eq 0 -and ($null -ne $data -and $data.GetType() -eq [System.Management.Automation.PSCustomObject])) { $__MtSession.GitHubCache[$key] = $result }
    return $result
}
