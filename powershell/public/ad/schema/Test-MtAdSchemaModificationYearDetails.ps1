function Test-MtAdSchemaModificationYearDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of Active Directory schema modifications by year.

    .DESCRIPTION
    This test analyzes the Active Directory schema to provide a detailed breakdown
    of schema modifications organized by year. It shows how many schema objects
    were created each year, helping identify periods of significant directory
    changes such as domain upgrades or application installations.

    .EXAMPLE
    Test-MtAdSchemaModificationYearDetails

    Returns $true if schema data is accessible, $false otherwise.
    The test result includes a breakdown of schema modifications per year.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSchemaModificationYearDetails
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

    $schemaObjects = $adState.SchemaObjects

    # Group schema objects by year and count modifications per year
    $modificationsByYear = $schemaObjects | Where-Object { $_.whenCreated } |
        Group-Object { $_.whenCreated.Year } |
        Select-Object Name, Count |
        Sort-Object Name

    $yearCount = ($modificationsByYear | Measure-Object).Count

    # Test passes if we successfully retrieved schema data
    $testResult = $null -ne $schemaObjects

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Schema Objects | $(($schemaObjects | Measure-Object).Count) |`n"
        $result += "| Years with Modifications | $yearCount |`n`n"

        $result += "**Schema Modifications by Year:**`n`n"
        $result += "| Year | Object Count | Percentage |`n"
        $result += "| --- | --- | --- |`n"

        $totalObjects = ($schemaObjects | Measure-Object).Count
        foreach ($yearData in $modificationsByYear) {
            $percentage = if ($totalObjects -gt 0) {
                [Math]::Round(($yearData.Count / $totalObjects) * 100, 2)
            } else {
                0
            }
            $result += "| $($yearData.Name) | $($yearData.Count) | $percentage% |`n"
        }

        $testResultMarkdown = "Active Directory schema modification details by year. Schema changes occurred across $yearCount different years.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory schema information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
