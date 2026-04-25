function Test-MtAdDcNonGlobalCatalogCount {
    <#
    .SYNOPSIS
    Counts domain controllers that are not configured as Global Catalogs.

    .DESCRIPTION
    This test identifies domain controllers that are not serving as Global Catalogs.
    Global Catalogs maintain a partial replica of all objects in the forest, enabling
    forest-wide searches and authentication for users from other domains. In a single-domain
    environment, all DCs should be GCs. In multi-domain forests, proper GC placement
    is critical for authentication and directory searches.

    .EXAMPLE
    Test-MtAdDcNonGlobalCatalogCount

    Returns $true if DC data is accessible.
    The test result includes the count of DCs with and without Global Catalog role.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcNonGlobalCatalogCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $domainControllers = $adState.DomainControllers
    $dcCount = ($domainControllers | Measure-Object).Count

    # Count GCs vs non-GCs
    $globalCatalogs = $domainControllers | Where-Object { $_.IsGlobalCatalog -eq $true }
    $gcCount = ($globalCatalogs | Measure-Object).Count
    $nonGcCount = $dcCount - $gcCount

    # Get forest info to determine if multi-domain
    $forestDomainCount = ($adState.Forest.Domains | Measure-Object).Count
    $isMultiDomain = $forestDomainCount -gt 1

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| Global Catalog Servers | $gcCount |`n"
    $result += "| Non-Global Catalog DCs | $nonGcCount |`n"
    $result += "| Forest Domain Count | $forestDomainCount |`n"

    if ($nonGcCount -gt 0) {
        $nonGcDCs = $domainControllers | Where-Object { $_.IsGlobalCatalog -eq $false }
        $result += "| Non-GC DC Names | $($nonGcDCs.Name -join ', ') |`n"

        if ($isMultiDomain) {
            $testResultMarkdown = "ℹ️ **Multi-Domain Forest**: $nonGcCount domain controller(s) are not Global Catalogs. In multi-domain environments, proper GC placement is critical. Ensure each site has at least one GC for optimal authentication performance.`n`n%TestResult%"
        } else {
            $testResultMarkdown = "⚠️ **Single-Domain Environment**: $nonGcCount domain controller(s) are not Global Catalogs. In single-domain forests, all DCs should typically be GCs for optimal performance and redundancy.`n`n%TestResult%"
        }
    } else {
        $testResultMarkdown = "✅ **Optimal Configuration**: All $dcCount domain controller(s) are configured as Global Catalogs.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
