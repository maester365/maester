function Get-MtAssetUniqueId {
    <#
    .SYNOPSIS
    Computes the stable unique id for an asset inventory record.

    .DESCRIPTION
    The id is derived from the asset identity (System/Type/Id) so the same object keeps the
    same unique id across runs and across tenants' reports. It is used as the replacement
    token when personally identifiable information is redacted from a report.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The system the asset lives in, for example EntraID.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $System,

        # The canonical asset type, for example User.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $Type,

        # The object id of the asset.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $Id
    )

    # Lower-cased to match the case-insensitive grouping in Get-MtAssetInventory: two cache reads
    # of the same resource that differ only in url casing merge into one record, and which casing
    # survives depends on hashtable enumeration order, so the hash must not depend on it.
    $identity = "$System|$Type|$Id".ToLowerInvariant()
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))
    } finally {
        $sha256.Dispose()
    }

    return 'asset-' + ([System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant().Substring(0, 16))
}
