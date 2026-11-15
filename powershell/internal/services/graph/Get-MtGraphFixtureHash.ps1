function Get-MtGraphFixtureHash {
    <#
    .SYNOPSIS
    Internal: Returns the lower-case hex SHA-256 (or, with -Salt, HMAC-SHA256) of a text.

    .DESCRIPTION
    Used by Graph record and replay for fixture keys and file names, and, with the fixture set's salt, to derive
    the stable fake values that sanitisation puts in place of tenant data.

    .EXAMPLE
    Get-MtGraphFixtureHash -Text 'GET v1.0/organization'

    Returns the SHA-256 of the key as 64 hex characters.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The text to hash, as UTF-8.
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string] $Text,

        # A secret that turns the hash into an HMAC, so fake values cannot be matched to real ones without it.
        [Parameter()]
        [string] $Salt
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $hash = if ($Salt) {
        $hmac = [System.Security.Cryptography.HMACSHA256]::new([System.Text.Encoding]::UTF8.GetBytes($Salt))
        try { $hmac.ComputeHash($bytes) } finally { $hmac.Dispose() }
    } else {
        [System.Security.Cryptography.SHA256]::HashData($bytes)
    }
    return [System.Convert]::ToHexString($hash).ToLowerInvariant()
}
