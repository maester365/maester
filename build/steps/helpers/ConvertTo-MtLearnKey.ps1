function ConvertTo-MtLearnKey {
    <#
    .SYNOPSIS
    Turns a Microsoft Learn URL into the key the step tooling indexes pages by.

    .DESCRIPTION
    The key is the URL's path with no locale, query, fragment or trailing slash, in lowercase: both
    https://learn.microsoft.com/intune/device-security/compliance/overview and the same page under a locale and with
    an anchor give intune/device-security/compliance/overview. Learn paths are not case-sensitive, so neither is the
    key. The site root gives an empty key.

    docs.microsoft.com URLs are read as Learn URLs, because Learn redirects them. Any other URL returns $null.

    .PARAMETER Url
    The URL to convert.

    .EXAMPLE
    ConvertTo-MtLearnKey 'https://learn.microsoft.com/entra/identity/conditional-access/overview#policy'

    Returns entra/identity/conditional-access/overview.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [AllowEmptyString()]
        [string] $Url
    )

    process {
        $match = [regex]::Match($Url, '^(?i)https?://(?:learn|docs)\.microsoft\.com(?<path>/[^?#\s]*)?')
        if (-not $match.Success) { return $null }
        $path = $match.Groups['path'].Value.Trim('/')
        $path = [regex]::Replace($path, '^[a-z]{2}-[a-z]{2}(/|$)', '', 'IgnoreCase')
        $path.Trim('/').ToLowerInvariant()
    }
}
