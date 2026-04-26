function Test-MtAdOuOverlappingNameCount {
    <#
    .SYNOPSIS
    Counts the number of Organizational Units with overlapping (duplicate) names in Active Directory.

    .DESCRIPTION
    This test identifies OUs that share the same name but exist in different locations within the directory.
    While this is technically allowed in Active Directory, overlapping OU names can cause confusion and
    administration errors, particularly when applying Group Policies or managing permissions.

    .EXAMPLE
    Test-MtAdOuOverlappingNameCount

    Returns $true if OU data is accessible, $false otherwise.
    The test result includes the count of OUs with duplicate names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdOuOverlappingNameCount
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

    $organizationalUnits = $adState.OrganizationalUnits

    # Count total OUs
    $totalCount = ($organizationalUnits | Measure-Object).Count

    # Find OUs with overlapping names
    $ouNameGroups = $organizationalUnits | Group-Object -Property Name
    $overlappingNames = $ouNameGroups | Where-Object { $_.Count -gt 1 }
    $overlappingNameCount = ($overlappingNames | Measure-Object).Count
    $affectedOuCount = ($overlappingNames | ForEach-Object { $_.Count } | Measure-Object -Sum).Sum

    # Test passes if we successfully retrieved OU data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total OUs | $totalCount |`n"
        $result += "| Duplicate OU Names | $overlappingNameCount |`n"
        $result += "| OUs with Duplicate Names | $affectedOuCount |`n`n"

        if ($overlappingNameCount -gt 0) {
            $result += "**Duplicate OU Names:**`n`n"
            $result += "| OU Name | Count | Distinguished Names |`n"
            $result += "| --- | --- | --- |`n"
            foreach ($group in $overlappingNames) {
                $dns = ($group.Group | ForEach-Object { $_.DistinguishedName }) -join "<br>"
                $result += "| $($group.Name) | $($group.Count) | $dns |`n"
            }
        }

        $testResultMarkdown = "Active Directory Organizational Units have been analyzed. $overlappingNameCount duplicate OU name(s) found affecting $affectedOuCount OU(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory Organizational Units. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


