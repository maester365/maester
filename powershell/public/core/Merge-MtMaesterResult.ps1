<#
 .Synopsis
  Merges multiple MaesterResults objects into a single multi-tenant result for combined HTML reporting.

 .Description
    Takes an array of MaesterResults objects (each from a separate Invoke-Maester run against
    a different tenant) and combines them into a single object with a "Tenants" array.
    The resulting object can be passed to Get-MtHtmlReport to generate a multi-tenant report
    with a tenant selector in the sidebar.

 .Parameter MaesterResults
    An array of MaesterResults objects, each representing test results from a different tenant.

 .Example
    # Run Maester against two tenants and merge the results
    $result1 = Invoke-Maester -PassThru
    # ... reconnect to second tenant ...
    $result2 = Invoke-Maester -PassThru

    $merged = Merge-MtMaesterResult -MaesterResults @($result1, $result2)
    $html = Get-MtHtmlReport -MaesterResults $merged
    $html | Out-File -FilePath "MultiTenantReport.html" -Encoding UTF8

.LINK
    https://maester.dev/docs/commands/Merge-MtMaesterResult
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
        if (-not ($result.PSObject.Properties.Name -contains 'Tests')) {
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
