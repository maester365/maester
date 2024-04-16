<#
.SYNOPSIS
    Enhanced version of Invoke-MgGraphRequest that supports caching.
#>
Function Invoke-MtGraphRequestCache {
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
        [switch] $DisableCache
    )

    $results = $null
    $isBatch = $uri.AbsoluteUri.EndsWith('$batch')
    $isInCache = $MtGraphCache.ContainsKey($Uri.AbsoluteUri)
    $cacheKey = $Uri.AbsoluteUri
    $isMethodGet = $Method -eq 'GET'

    if (!$DisableCache -and !$isBatch -and $isInCache -and $isMethodGet) {
        # Don't read from cache for batch requests.
        Write-Verbose ("Checking cache: $($cacheKey)")
        $results = $MtGraphCache[$cacheKey]
    }

    if (!$results) {
        Write-Verbose ("Invoking Graph: $($Uri.AbsoluteUri)")
        $results = Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers -OutputType $OutputType
        if (!$isBatch -and $isMethodGet) {
            # Update cache
            if ($isInCache) {
                $MtGraphCache[$cacheKey] = $results
            } else {
                $MtGraphCache.Add($cacheKey, $results)
            }
        }
    }
    return $results
}