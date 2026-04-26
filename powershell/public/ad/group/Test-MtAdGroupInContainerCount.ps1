function Test-MtAdGroupInContainerCount {
    <#
    .SYNOPSIS
    Counts groups located in container objects (CN=) instead of Organizational Units (OU=).

    .DESCRIPTION
    This test identifies groups that are stored in container objects (distinguished names starting with 'CN=')
    rather than Organizational Units (OU=). Groups should typically be organized within OUs to allow for
    proper delegation, Group Policy application, and logical organization. Storing groups in containers
    like the default 'CN=Users' is considered poor practice and limits administrative flexibility.

    .EXAMPLE
    Test-MtAdGroupInContainerCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of groups in container objects.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupInContainerCount
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

    $groups = $adState.Groups

    # Count groups in containers (CN=) vs OUs (OU=)
    $groupsInContainers = $groups | Where-Object {
        $_.DistinguishedName -and $_.DistinguishedName -match '^CN='
    }

    $containerCount = ($groupsInContainers | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count
    $ouCount = $totalCount - $containerCount

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($containerCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Groups in OUs (OU=) | $ouCount |`n"
        $result += "| Groups in Containers (CN=) | $containerCount |`n"
        $result += "| Container Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $containerCount out of $totalCount groups ($percentage%) are located in container objects (CN=) rather than Organizational Units.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


