function Test-MtAdSchemaModificationYearCount {
    <#
    .SYNOPSIS
    Counts the number of years with Active Directory schema modifications.

    .DESCRIPTION
    This test analyzes the Active Directory schema to identify how many different years
    have had schema modifications. Schema changes indicate when the directory has been
    extended with new object classes or attributes, which is typically done during
    domain upgrades or application installations.

    .EXAMPLE
    Test-MtAdSchemaModificationYearCount

    Returns $true if schema data is accessible, $false otherwise.
    The test result includes the count of years with schema modifications.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdSchemaModificationYearCount
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

    # Count unique years with schema modifications
    $yearsWithModifications = $schemaObjects | Where-Object { $_.whenCreated } |
        ForEach-Object { $_.whenCreated.Year } |
        Sort-Object -Unique

    $yearCount = ($yearsWithModifications | Measure-Object).Count

    # Test passes if we successfully retrieved schema data
    $testResult = $null -ne $schemaObjects

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Schema Objects | $(($schemaObjects | Measure-Object).Count) |`n"
        $result += "| Years with Modifications | $yearCount |`n"
        $result += "| First Schema Change | $(($yearsWithModifications | Sort-Object | Select-Object -First 1)) |`n"
        $result += "| Most Recent Schema Change | $(($yearsWithModifications | Sort-Object | Select-Object -Last 1)) |`n`n"

        $result += "**Years with Schema Modifications:**`n`n"
        $result += "| Year |`n"
        $result += "| --- |`n"
        foreach ($year in ($yearsWithModifications | Sort-Object)) {
            $result += "| $year |`n"
        }

        $testResultMarkdown = "Active Directory schema has been modified across $yearCount different years.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory schema information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


