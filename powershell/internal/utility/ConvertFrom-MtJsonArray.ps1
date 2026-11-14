function ConvertFrom-MtJsonArray {
    <#
    .SYNOPSIS
    Reads a JSON array that arrived as text and returns its items, or an empty array.

    .DESCRIPTION
    Azure Resource Graph has no `mv-apply`, so a query that needs to return an array packs it
    into a JSON string. This unpacks it. Empty, whitespace and malformed text all return an
    empty array rather than throwing: the caller is building a report row, and a value it
    cannot parse is a missing value, not a reason to fail the check.

    .EXAMPLE
    ConvertFrom-MtJsonArray -Text '["a","b"]'

    Returns a and b.
    #>
    [CmdletBinding()]
    [OutputType([object[]])]
    param(
        [string] $Text
    )

    if ([string]::IsNullOrWhiteSpace($Text)) { return @() }
    try { return @($Text | ConvertFrom-Json) } catch { return @() }
}
