function Merge-MtMaesterResult {
    <#
     .Synopsis
      Merges multiple MaesterResults objects into a single multi-tenant result for combined HTML reporting.

     .Description
        Takes an array of MaesterResults objects (each from a separate Invoke-Maester run against
        a different tenant) and combines them into a single object with a "Tenants" array.
        The resulting object can be passed to Get-MtHtmlReport to generate a multi-tenant report
        with a tenant selector in the sidebar.

        Accepts either in-memory MaesterResults objects (from Invoke-Maester -PassThru or pipeline)
        or file paths/directories that are loaded automatically via Import-MtMaesterResult.

        All results are included as-is - no deduplication is performed when the same TenantId
        appears multiple times. This is by design to support future scenarios such as historical
        trend reports where multiple runs from the same tenant are intentional.

     .Parameter MaesterResults
        An array of MaesterResults objects, each representing test results from a different tenant.
        Accepts pipeline input from Import-MtMaesterResult.

     .Parameter Path
        One or more paths to JSON result files, glob patterns, or directories.
        Files are loaded via Import-MtMaesterResult internally.
        - File path:  ./production.json
        - Glob:       ./results/*.json
        - Directory:  ./results/  (discovers TestResults-*.json inside)

     .Example
        # Merge from file paths (one-liner)
        Merge-MtMaesterResult -Path ./production.json, ./development.json | Get-MtHtmlReport | Out-File report.html

     .Example
        # Merge from a directory of JSON files
        Merge-MtMaesterResult -Path ./results/ | Get-MtHtmlReport | Out-File report.html

     .Example
        # Merge from a glob pattern
        Merge-MtMaesterResult -Path *.json | Get-MtHtmlReport | Out-File report.html

     .Example
        # Pipeline: Import then merge
        Import-MtMaesterResult -Path *.json | Merge-MtMaesterResult | Get-MtHtmlReport | Out-File report.html

     .Example
        # In-memory: run against two tenants and merge
        $result1 = Invoke-Maester -PassThru
        # ... reconnect to second tenant ...
        $result2 = Invoke-Maester -PassThru

        $merged = Merge-MtMaesterResult -MaesterResults @($result1, $result2)
        $html = Get-MtHtmlReport -MaesterResults $merged
        $html | Out-File -FilePath "MultiTenantReport.html" -Encoding UTF8

    .LINK
        https://maester.dev/docs/commands/Merge-MtMaesterResult

    .NOTES
        ## Design notes for future development

        ### Multi-tenant reports (current)
        This command wraps all results into a Tenants[] array. The HTML report frontend
        detects the Tenants property and renders a tenant selector in the sidebar.
        No deduplication is performed - if the same TenantId appears multiple times,
        all instances are included.

        ### Historical / trend reports (planned)
        A future command (e.g. New-MtTrendReport) can reuse Import-MtMaesterResult to
        load results, then group by TenantId and sort by ExecutedAt within each group.
        Each result already carries TenantId and ExecutedAt, so the intelligence is:

          - Different TenantIds, similar dates  -> multi-tenant (use Merge-MtMaesterResult)
          - Same TenantId, different dates      -> historical trend (use future trend command)
          - Mixed                               -> group by TenantId, each group has a timeline

        Import-MtMaesterResult is intentionally a "dumb loader" that returns everything.
        The consuming command (Merge, Compare, Trend) decides how to interpret the data.

        ### Pipeline architecture
        The intended pipeline pattern is:

          Import-MtMaesterResult -> [Merge | Compare | Trend] -> Get-MtHtmlReport -> Out-File

        Merge-MtMaesterResult also accepts -Path directly for convenience (calls Import
        internally), so the user can skip the Import step for simple scenarios:

          Merge-MtMaesterResult -Path *.json | Get-MtHtmlReport | Out-File report.html
    #>
    [CmdletBinding(DefaultParameterSetName = 'FromObjects')]
    param(
        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'FromObjects', ValueFromPipeline = $true)]
        [psobject[]] $MaesterResults,

        [Parameter(Mandatory = $true, Position = 0, ParameterSetName = 'FromPath')]
        [string[]] $Path
    )

    begin {
        $collectedResults = [System.Collections.Generic.List[psobject]]::new()
    }

    process {
        if ($PSCmdlet.ParameterSetName -eq 'FromObjects') {
            # Collect pipeline input - may arrive one object at a time
            foreach ($result in $MaesterResults) {
                $collectedResults.Add($result)
            }
        }
    }

    end {
        # If -Path was used, load files via Import-MtMaesterResult
        if ($PSCmdlet.ParameterSetName -eq 'FromPath') {
            $imported = Import-MtMaesterResult -Path $Path
            if ($null -eq $imported -or $imported.Count -eq 0) {
                throw "No valid Maester results found at the specified path(s): $($Path -join ', ')"
            }
            foreach ($result in $imported) {
                $collectedResults.Add($result)
            }
        }

        if ($collectedResults.Count -eq 0) {
            throw "At least one MaesterResults object is required."
        }

        # Validate each result has the expected structure
        foreach ($result in $collectedResults) {
            if (-not ($result.PSObject.Properties.Name -contains 'Tests')) {
                throw "MaesterResults object is missing the 'Tests' property. TenantId: $($result.TenantId)"
            }
        }

        Write-Verbose "Merging $($collectedResults.Count) tenant results into a multi-tenant report."

        $firstResult = $collectedResults[0]

        # Always wrap in Tenants array, even for a single tenant
        $merged = [PSCustomObject]@{
            Tenants        = @($collectedResults)
            CurrentVersion = $firstResult.CurrentVersion
            LatestVersion  = $firstResult.LatestVersion
            EndOfJson      = "EndOfJson"
        }

        return $merged
    }
}
