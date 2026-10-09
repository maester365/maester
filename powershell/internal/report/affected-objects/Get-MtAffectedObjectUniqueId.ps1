function Get-MtAffectedObjectUniqueId {
    <#
    .SYNOPSIS
    Computes the stable unique id for the affected objects record.

    .DESCRIPTION
    The id is derived from the object identity (System/Type/Id) so the same object keeps the
    same unique id across runs and across tenants' reports. It is used as the replacement
    token when personally identifiable information is redacted from a report.
    #>
    [CmdletBinding()]
    [OutputType([string])]
    param(
        # The system the object lives in, for example EntraID.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $System,

        # The canonical object type, for example User.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $Type,

        # The object id of the object.
        [Parameter(Mandatory = $false)]
        [AllowNull()]
        [string] $Id
    )

    # Lower-cased to match the case-insensitive grouping in Get-MtAffectedObject: two cache reads
    # of the same resource that differ only in url casing merge into one record, and which casing
    # survives depends on hashtable enumeration order, so the hash must not depend on it.
    $identity = "$System|$Type|$Id".ToLowerInvariant()
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($identity))
    } finally {
        $sha256.Dispose()
    }

    return 'object-' + ([System.BitConverter]::ToString($hash).Replace('-', '').ToLowerInvariant().Substring(0, 16))
}
