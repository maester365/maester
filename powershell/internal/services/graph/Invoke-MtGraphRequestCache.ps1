function Invoke-MtGraphRequestCache {
    <#
    .SYNOPSIS
    Enhanced version of Invoke-MgGraphRequest that supports caching.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [Uri] $Uri,
        [Parameter(Mandatory = $false)]
        [string] $Method = 'GET',
        [Parameter(Mandatory = $false)]
        [string] $OutputType,
        [Parameter(Mandatory = $false)]
        [System.Collections.IDictionary] $Headers,
        # Specify if this request should skip cache and go directly to Graph.
        [Parameter(Mandatory = $false)]
        [switch] $DisableCache,
        [string] $Body
    )

    $results = $null
    if ($Method -eq 'GET') {
        $cacheKey = $Uri.AbsoluteUri
        $isMethodGet = $true
    } elseif ($Method -eq 'POST' -and $Uri.AbsoluteUri.EndsWith('security/runHuntingQuery')) {
        $cacheKey = $Uri.AbsoluteUri + "_" + ($Body -replace '\s', '')
        $isXdrQuery = $true
    } else {
        $cacheKey = $Uri.AbsoluteUri + "_" + ($Body -replace '\s', '')
        $isMethodGet = $false
   }

    $isBatch = $uri.AbsoluteUri.EndsWith('$batch')
    $isInCache = $__MtSession.GraphCache.ContainsKey($cacheKey)


    if (!$DisableCache -and !$isBatch -and $isInCache -and ($isMethodGet -or $isXdrQuery)) {
        # Don't read from cache for batch requests.
        Write-Verbose ("Using graph cache: $($cacheKey)")
        $results = $__MtSession.GraphCache[$cacheKey]
    }

    if (!$results) {
        Write-Verbose ("Invoking Graph: $($Uri.AbsoluteUri)")
        Write-Verbose ([string]::IsNullOrEmpty($Body))

        # The Graph SDK already retries 429, 503 and 504. Retry 500 and 502 for requests that are safe to repeat.
        $maxRetries = 2
        $attempt = 0
        while ($true) {
            try {
                if ($Method -eq 'GET') {
                    $results = Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers -OutputType $OutputType # -Body $Body # Cannot use Body with GET in PS 5.1
                } else {
                    $results = Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers -OutputType $OutputType -Body $Body
                }
                break
            } catch {
                $response = $_.Exception.Response
                $statusCode = if ($response) { [int]$response.StatusCode } else { 0 }
                if ($attempt -ge $maxRetries -or !($isMethodGet -or $isXdrQuery) -or $statusCode -notin 500, 502) {
                    $PSCmdlet.ThrowTerminatingError($_)
                }
                $attempt++
                $delay = [Math]::Pow(2, $attempt)
                if ($response.Headers.RetryAfter.Delta) {
                    $delay = [Math]::Min($response.Headers.RetryAfter.Delta.TotalSeconds, 30)
                }
                Write-Verbose ("Graph returned $statusCode, retrying in $delay seconds ($attempt of $maxRetries): $($Uri.AbsoluteUri)")
                Start-Sleep -Seconds $delay
            }
        }

        if (!$isBatch -and $isMethodGet) {
            # Update cache
            if ($isInCache) {
                $__MtSession.GraphCache[$cacheKey] = $results
            } else {
                $__MtSession.GraphCache.Add($cacheKey, $results)
            }
        } elseif ($isXdrQuery) {
            if ($isInCache) {
                $__MtSession.GraphCache[$cacheKey] = $results
            } else {
                $__MtSession.GraphCache.Add($cacheKey, $results)
            }
        }
    }
    return $results
}
