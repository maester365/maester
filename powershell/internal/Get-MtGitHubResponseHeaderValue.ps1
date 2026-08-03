function Get-MtGitHubResponseHeaderValue {
    param(
        [Parameter()] $Headers,
        [Parameter(Mandatory)] [string] $Name
    )
    if ($null -eq $Headers) { return $null }
    # IDictionary covers PS 5.1 WebHeaderCollection and PS 7 Dictionary.
    # Iterate keys with -ieq for case-insensitive match (plain hashtables are case-sensitive).
    if ($Headers -is [System.Collections.IDictionary]) {
        foreach ($key in $Headers.Keys) {
            if ($key -ieq $Name) {
                $value = $Headers[$key]
                if ($value -is [array]) { return $value[0] }
                return $value
            }
        }
        return $null
    }
    # HttpResponseHeaders in PS 7 exposes GetValues / TryGetValues
    if ($Headers.PSObject.Methods.Name -contains 'GetValues') {
        try { return ($Headers.GetValues($Name) | Select-Object -First 1) } catch {
            Write-Debug "Get-MtGitHubResponseHeaderValue GetValues: $($_.Exception.Message)"
        }
    }
    if ($Headers.PSObject.Methods.Name -contains 'TryGetValues') {
        try {
            $values = $null
            if ($Headers.TryGetValues($Name, [ref]$values)) {
                return ($values | Select-Object -First 1)
            }
        } catch {
            Write-Debug "Get-MtGitHubResponseHeaderValue TryGetValues: $($_.Exception.Message)"
        }
    }
    return $null
}
