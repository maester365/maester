function Get-MtGraphFixtureKey {
    <#
    .SYNOPSIS
    Internal: Returns the stable key and file name of the fixture for one Microsoft Graph request.

    .DESCRIPTION
    Graph record and replay (Enable-MtGraphFixture) keeps one file per request. The key is built from the parts of
    the request that decide its response, normalised so that the same request always gets the same key:

      - the HTTP method, in upper case
      - the API version (v1.0 or beta), from the uri, or -ApiVersion when the uri has none (batch requests)
      - the path, without the endpoint, percent-decoded and in lower case (Graph paths are not case-sensitive)
      - the query parameters, sorted by name and value, names in lower case, values decoded and kept as they are
      - when there is a body, a SHA-256 hash of it, with the members of every JSON object sorted by name

    Headers such as ConsistencyLevel are not part of the key. The endpoint is not part of it either, so a fixture
    set recorded in one cloud replays in any other.

    The file name is readable (method, version and path) and ends in a hash of the whole key, so two requests that
    differ only in their query or body get a file each.

    .EXAMPLE
    Get-MtGraphFixtureKey -Uri 'https://graph.microsoft.com/v1.0/users?$top=5&$select=id' -Method GET

    Returns the key 'GET v1.0/users?$select=id&$top=5' and its file name.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        # The request uri: absolute, or relative with or without the API version.
        [Parameter(Mandatory)]
        [string] $Uri,

        # The HTTP method.
        [Parameter()]
        [string] $Method = 'GET',

        # The request body, as JSON text.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Body,

        # The API version of a uri that does not start with one, as in a batch request.
        [Parameter()]
        [ValidateSet('v1.0', 'beta')]
        [string] $ApiVersion = 'v1.0'
    )

    $text = $Uri.Trim()
    # An absolute uri loses its scheme and host: the key does not depend on the cloud.
    if ($text -match '^[A-Za-z][A-Za-z0-9+.-]*://[^/?#]*(?<rest>.*)$') { $text = $Matches['rest'] }
    $text = $text.TrimStart('/')

    $queryText = ''
    $queryStart = $text.IndexOf('?')
    if ($queryStart -ge 0) {
        $queryText = $text.Substring($queryStart + 1)
        $text = $text.Substring(0, $queryStart)
    }

    $segments = @($text -split '/' | Where-Object { $_ -ne '' } | ForEach-Object { [uri]::UnescapeDataString($_) })
    $version = $ApiVersion
    if ($segments.Count -gt 0 -and $segments[0] -in 'v1.0', 'beta') {
        $version = $segments[0].ToLowerInvariant()
        $segments = @($segments | Select-Object -Skip 1)
    }
    $path = ($segments -join '/').ToLowerInvariant()

    # Query strings are form encoded by ConvertTo-QueryString, so a plus sign is a space.
    $decode = { param($value) [uri]::UnescapeDataString(($value -replace '\+', ' ')) }
    $pairs = [System.Collections.Generic.List[object]]::new()
    foreach ($part in ($queryText -split '&')) {
        if ([string]::IsNullOrEmpty($part)) { continue }
        $equals = $part.IndexOf('=')
        $name = if ($equals -ge 0) { $part.Substring(0, $equals) } else { $part }
        $value = if ($equals -ge 0) { $part.Substring($equals + 1) } else { '' }
        $pairs.Add([pscustomobject]@{ Name = (& $decode $name).ToLowerInvariant(); Value = (& $decode $value) })
    }
    # Ordinal order, so the key is the same on every machine and culture.
    [object[]] $sortedPairs = $pairs.ToArray()
    [System.Array]::Sort($sortedPairs, [System.Comparison[object]] {
            param($a, $b)
            $byName = [string]::CompareOrdinal($a.Name, $b.Name)
            if ($byName -ne 0) { return $byName }
            return [string]::CompareOrdinal($a.Value, $b.Value)
        })
    $query = ($sortedPairs | ForEach-Object { '{0}={1}' -f $_.Name, $_.Value }) -join '&'

    $bodyHash = $null
    if (-not [string]::IsNullOrWhiteSpace($Body)) {
        $canonical = ConvertTo-MtGraphFixtureJson -Json $Body -Compress -Sort
        $bodyHash = (Get-MtGraphFixtureHash -Text $canonical).Substring(0, 16)
    }

    $methodUpper = $Method.ToUpperInvariant()
    $relativeUri = "$version/$path"
    if ($query) { $relativeUri += "?$query" }
    $key = "$methodUpper $relativeUri"
    if ($bodyHash) { $key += " body:$bodyHash" }

    $slug = ("$version/$path" -replace '/', '_') -replace '[^A-Za-z0-9._-]+', '-'
    if ($slug.Length -gt 80) { $slug = $slug.Substring(0, 80) }
    $fileName = '{0}_{1}_{2}.json' -f $methodUpper.ToLowerInvariant(), $slug.Trim('-'), (Get-MtGraphFixtureHash -Text $key).Substring(0, 10)

    [pscustomobject]@{
        PSTypeName  = 'Maester.GraphFixtureKey'
        Key         = $key
        Method      = $methodUpper
        ApiVersion  = $version
        Path        = $path
        Query       = $sortedPairs
        RelativeUri = $relativeUri
        BodyHash    = $bodyHash
        FileName    = $fileName
    }
}
