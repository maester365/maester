function Test-MtAdGpoChangedBefore2020Count {
    <#
    .SYNOPSIS
    Counts Group Policy Objects (GPOs) last changed before 2020.

    .DESCRIPTION
    This test counts GPOs whose ModificationTime is earlier than 2020-01-01.
    These GPOs can be considered "stale" and may contain outdated security configurations.

    Stale or unmaintained GPOs can create security gaps if they no longer align with
    current security baselines and organizational requirements.

    .EXAMPLE
    Test-MtAdGpoChangedBefore2020Count

    Returns $true if the cached GPO data is accessible, $null if Active Directory data
    cannot be retrieved.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoChangedBefore2020Count
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD GPO state data (uses cached data if available)
    $gpoState = Get-MtADGpoState

    # If unable to retrieve GPO data, skip the test
    if ($null -eq $gpoState -or $null -eq $gpoState.GPOs) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpos = $gpoState.GPOs

    $staleDate = [datetime]'2020-01-01'
    $staleGpos = @(
        $gpos | Where-Object {
            $null -ne $_.ModificationTime -and ([datetime]$_.ModificationTime -lt $staleDate)
        }
    )

    # Counts
    $totalCount = ($gpos | Measure-Object).Count
    $staleCount = ($staleGpos | Measure-Object).Count
    $stalePercentage = if ($totalCount -gt 0) { [math]::Round(($staleCount / $totalCount) * 100, 2) } else { 0 }

    # Data retrieved successfully
    $testResult = $true

    # Generate markdown results
    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPOs | $totalCount |`n"
    $resultTable += "| Stale GPOs (Modified before 2020-01-01) | $staleCount |`n"
    $resultTable += "| Stale GPOs % | $stalePercentage% |`n"

    if ($staleCount -gt 0) {
        $recommendation = "⚠️ Found $staleCount stale GPO(s) (not modified since before 2020-01-01). Stale policies can contain outdated security settings and create security gaps. Consider regular review and remediation of unchanged policies."
    } else {
        $recommendation = "✅ No stale GPOs were detected (no GPOs have a ModificationTime earlier than 2020-01-01). Continue periodic reviews to ensure security configurations remain current."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



