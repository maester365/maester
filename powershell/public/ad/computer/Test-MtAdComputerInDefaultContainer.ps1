function Test-MtAdComputerInDefaultContainer {
    <#
    .SYNOPSIS
    Counts computers located in the default Computers container.

    .DESCRIPTION
    This test identifies computer objects that are still located in the default
    CN=Computers container instead of being organized in organizational units (OUs).
    Best practice is to organize computers into appropriate OUs for better management
    and Group Policy application. Computers in the default container may indicate:
    - Default domain join process not customized
    - Lack of organizational structure
    - Potential management gaps

    .EXAMPLE
    Test-MtAdComputerInDefaultContainer

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of computers in the default Computers container.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerInDefaultContainer
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

    # Count enabled computers in the default Computers container
    $defaultContainerComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.DistinguishedName -and
        $_.DistinguishedName -like "CN=Computers,*"
    }

    $defaultContainerCount = ($defaultContainerComputers | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($defaultContainerCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| In Default Computers Container | $defaultContainerCount |`n"
        $result += "| Default Container Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $defaultContainerCount out of $enabledCount enabled computers ($percentage%) are located in the default Computers container.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


