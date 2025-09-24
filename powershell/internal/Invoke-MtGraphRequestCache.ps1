<#
.SYNOPSIS
    Enhanced version of Invoke-MgGraphRequest that supports caching.
#>
function Invoke-MtGraphRequestCache {
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

        if ($Method -eq 'GET') {
            $results = Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers -OutputType $OutputType # -Body $Body # Cannot use Body with GET in PS 5.1
        } else {
            $results = Invoke-MgGraphRequest -Method $Method -Uri $Uri -Headers $Headers -OutputType $OutputType -Body $Body
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