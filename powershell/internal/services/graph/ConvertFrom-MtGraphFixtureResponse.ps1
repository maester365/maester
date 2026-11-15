function ConvertFrom-MtGraphFixtureResponse {
    <#
    .SYNOPSIS
    Internal: Converts a Graph response body (JSON text) into the shape Invoke-MgGraphRequest returns for -OutputType.

    .DESCRIPTION
    Record and replay both return responses through this function, so a test sees the same objects when it is
    recorded as when it is replayed. PSObject and PSCustomObject give objects (ConvertFrom-Json), Json gives the text,
    and anything else (HashTable, the default of Invoke-MgGraphRequest) gives hashtables.

    .EXAMPLE
    ConvertFrom-MtGraphFixtureResponse -Json '{"value":[]}' -OutputType PSObject

    Returns an object with an empty value property.
    #>
    [CmdletBinding()]
    [OutputType([object])]
    param(
        # The response body. An empty body returns $null.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $Json,

        # The -OutputType the caller asked Invoke-MgGraphRequest for.
        [Parameter()]
        [AllowNull()]
        [AllowEmptyString()]
        [string] $OutputType
    )

    if ([string]::IsNullOrWhiteSpace($Json)) { return $null }
    switch ($OutputType) {
        'Json' { return $Json }
        { $_ -in 'PSObject', 'PSCustomObject' } { return (ConvertFrom-Json -InputObject $Json -Depth 100) }
        default { return (ConvertFrom-Json -InputObject $Json -Depth 100 -AsHashtable) }
    }
}
