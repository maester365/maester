function Test-MtAdComputerOUCount {
    <#
    .SYNOPSIS
    Counts the distinct organizational units (OUs) containing computer objects.

    .DESCRIPTION
    This test identifies the number of unique organizational units that contain
    enabled computer objects. This provides insight into the organizational structure
    and distribution of computers across the directory. A well-organized AD structure
    typically has computers distributed across multiple OUs based on location,
    department, or function.

    .EXAMPLE
    Test-MtAdComputerOUCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of distinct OUs with computers.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerOUCount
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

    # Extract the parent container (OU) from DistinguishedName
    $computerContainers = $enabledComputers | ForEach-Object {
        $dn = $_.DistinguishedName
        # Extract the container by removing the CN=ComputerName prefix
        if ($dn -match '^CN=[^,]+,(.+)$') {
            $matches[1]
        }
    } | Select-Object -Unique

    $distinctOUCount = ($computerContainers | Measure-Object).Count
    $enabledCount = ($enabledComputers | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Distinct OUs/Containers | $distinctOUCount |`n`n"

        if ($distinctOUCount -gt 0) {
            $result += "**Sample Containers:**`n`n"
            $computerContainers | Select-Object -First 10 | ForEach-Object {
                $result += "- $_`n"
            }
            if ($computerContainers.Count -gt 10) {
                $result += "- ... and $($computerContainers.Count - 10) more`n"
            }
        }

        $testResultMarkdown = "Active Directory computer objects have been analyzed. Computers are distributed across $distinctOUCount distinct organizational units/containers.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


