function Test-MtAdComputerPerOUAverage {
    <#
    .SYNOPSIS
    Calculates the average number of computers per organizational unit.

    .DESCRIPTION
    This test calculates the average number of enabled computer objects per
    distinct organizational unit/container. This metric helps understand the
    distribution density of computers across the directory structure and can
    identify OUs that may be overloaded or underutilized.

    .EXAMPLE
    Test-MtAdComputerPerOUAverage

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the average computers per OU and distribution details.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerPerOUAverage
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

    $computers = $adState.Computers

    # Get enabled computers and extract their OU/container
    $enabledComputers = $computers | Where-Object { $_.Enabled -eq $true -and $_.DistinguishedName }

    # Group computers by their parent container
    $computersByContainer = $enabledComputers | Group-Object -Property {
        $dn = $_.DistinguishedName
        # Extract the container by removing the CN=ComputerName prefix
        if ($dn -match '^CN=[^,]+,(.+)$') {
            $matches[1]
        }
    }

    $distinctOUCount = $computersByContainer.Count
    $enabledCount = ($enabledComputers | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Calculate average
    $averagePerOU = if ($distinctOUCount -gt 0) {
        [Math]::Round($enabledCount / $distinctOUCount, 2)
    } else {
        0
    }

    # Find min and max
    $minCount = if ($computersByContainer.Count -gt 0) {
        ($computersByContainer | Measure-Object -Property Count -Minimum).Minimum
    } else {
        0
    }
    $maxCount = if ($computersByContainer.Count -gt 0) {
        ($computersByContainer | Measure-Object -Property Count -Maximum).Maximum
    } else {
        0
    }

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Distinct OUs/Containers | $distinctOUCount |`n"
        $result += "| Average Computers per OU | $averagePerOU |`n"
        $result += "| Minimum Computers in OU | $minCount |`n"
        $result += "| Maximum Computers in OU | $maxCount |`n`n"

        if ($distinctOUCount -gt 0) {
            $result += "**Top 5 Containers by Computer Count:**`n`n"
            $computersByContainer |
                Sort-Object -Property Count -Descending |
                Select-Object -First 5 |
                ForEach-Object {
                    $result += "| $($_.Name) | $($_.Count) |`n"
                }
        }

        $testResultMarkdown = "Active Directory computer objects have been analyzed. The average number of computers per organizational unit is $averagePerOU.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


