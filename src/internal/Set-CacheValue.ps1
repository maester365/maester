

function Set-CacheValue {
    [CmdletBinding()]

    param(
        # The unique key for the value to be retrieved.
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string] $Key,
        # The value that is being saved
        [Parameter(Mandatory = $true, Position = 1, ValueFromPipeline = $true)]
        [object] $Value
    )

    if ($MtGraphCache.ContainsKey($Key)) {
        $MtGraphCache[$Key] = $Value
    } else { $MtGraphCache.Add($Key, $Value) }
}