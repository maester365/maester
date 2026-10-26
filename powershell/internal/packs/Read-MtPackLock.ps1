function Read-MtPackLock {
    <#
    .SYNOPSIS
    Reads maester-packs.lock.json (Maester Packs design, section 5.2), or returns an empty lock.

    .DESCRIPTION
    The lock file pins every installed pack, and every pack it requires, to what was approved:

      Packs[]    Id, Version, Source, Ref, Commit, RepositoryId, OwnerId, Publisher, Digest, Tests (the IDs
                 the pack provides), Services (its connectors), Requires (the IDs of required packs), Risk
                 (the local scan at install), AcceptedRisk, Uses (the approved Uses block), ApprovedAt,
                 ReleasePublishedAt and Cooldown (how the release cooldown was met).
      Modules[]  the whole PowerShell Gallery module closure: Name, Version, Digest, Source (PSGallery, or
                 External for a module the user installed) and RequiredBy (pack IDs).

    A lock file that is not valid JSON, or has a newer LockVersion, throws: a pack must never run from a
    lock that could not be read.
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)]
        [string] $Path
    )

    $empty = [pscustomobject]@{ LockVersion = 1; Packs = @(); Modules = @() }
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $empty }
    $text = Get-Content -LiteralPath $Path -Raw
    if ([string]::IsNullOrWhiteSpace($text)) { return $empty }
    try { $lock = $text | ConvertFrom-Json -ErrorAction Stop }
    catch { throw "The pack lock file '$Path' is not valid JSON: $($_.Exception.Message)" }
    if ($lock.PSObject.Properties['LockVersion'] -and [int]$lock.LockVersion -gt 1) {
        throw "The pack lock file '$Path' was written by a newer version of Maester (LockVersion $($lock.LockVersion)). Update Maester."
    }
    [pscustomobject]@{
        LockVersion = 1
        Packs       = @($(if ($lock.PSObject.Properties['Packs']) { $lock.Packs }) | Where-Object { $_ })
        Modules     = @($(if ($lock.PSObject.Properties['Modules']) { $lock.Modules }) | Where-Object { $_ })
    }
}
