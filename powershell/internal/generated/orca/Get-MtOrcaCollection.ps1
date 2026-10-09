function Get-MtOrcaCollection {
    <#
    .SYNOPSIS
    Returns the ORCA configuration collection for the ORCA tests, reading it from Exchange Online once per session.

    .DESCRIPTION
    The ORCA native tests (tests/orca) all evaluate the same collection of Exchange Online and Defender for
    Office 365 settings. The first call reads it with Get-ORCACollection, including the Security & Compliance
    entries when that service is connected, and caches it in the module session. Clear-MtExoCache clears it.

    Tests reach the cache only through this helper (Maester 3.0 design, section 13). It returns a copy of
    the collection table, so a test cannot add or replace entries that the tests after it would see.

    .EXAMPLE
    $Collection = Get-MtOrcaCollection
    #>
    [CmdletBinding()]
    [OutputType([hashtable])]
    param()

    if (-not $__MtSession.OrcaCache -or $__MtSession.OrcaCache.Count -eq 0) {
        Write-Verbose 'OrcaCache not set, Get-ORCACollection'
        # Specify SCC to include the checks that need Security & Compliance data.
        $scc = [bool](Test-MtConnection SecurityCompliance)
        $__MtSession.OrcaCache = Get-ORCACollection -SCC:$scc
    }
    return $__MtSession.OrcaCache.Clone()
}
