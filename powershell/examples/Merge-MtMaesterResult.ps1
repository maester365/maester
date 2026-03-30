<#
 .Synopsis
  Merges multiple MaesterResults objects into a single multi-tenant result for combined HTML reporting.

 .Description
    Takes an array of MaesterResults objects (each from a separate Invoke-Maester run against
    a different tenant) and combines them into a single object with a "Tenants" array.
    The resulting object can be passed to New-MtMultiTenantHtmlReport to generate a
    multi-tenant report with a tenant selector in the sidebar.
#>
function Merge-MtMaesterResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true, Position = 0)]
        [psobject[]] $MaesterResults
    )

    if ($MaesterResults.Count -eq 0) {
        throw "At least one MaesterResults object is required."
    }

    # Validate each result has the expected structure
    foreach ($result in $MaesterResults) {
        if (-not $result.PSObject.Properties.Name -contains 'Tests') {
            throw "MaesterResults object is missing the 'Tests' property. TenantId: $($result.TenantId)"
        }
    }

    Write-Verbose "Merging $($MaesterResults.Count) tenant results into a multi-tenant report."

    $firstResult = $MaesterResults[0]

    # Always wrap in Tenants array, even for a single tenant
    $merged = [PSCustomObject]@{
        Tenants        = @($MaesterResults)
        CurrentVersion = $firstResult.CurrentVersion
        LatestVersion  = $firstResult.LatestVersion
        EndOfJson      = "EndOfJson"
    }

    return $merged
}
