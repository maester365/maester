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
    [MaesterTest(
        Id = 'AD-COMP-06',
        Title = 'Enabled computers should be moved out of the default Computers container',
        Product = 'ad',
        Feature = 'computers',
        Area = 'infrastructure',
        ResourceType = 'Computer',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerInDefaultContainer"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Computers')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState -or $null -eq $adState.Computers) { throw 'Computer inventory is required to review the default container.' }

    $computers = $adState.Computers
    if (@($computers).Count -eq 0) { throw 'Computer inventory is empty; default container placement cannot be assessed.' }
    if (@($computers | Where-Object { $null -eq $_.Enabled -or ($_.Enabled -eq $true -and -not $_.DistinguishedName) }).Count -gt 0) {
        throw 'Computer enabled state or distinguished name is missing; container placement cannot be assessed completely.'
    }

    # Count enabled computers in the default Computers container
    $defaultContainerComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.DistinguishedName -and
        $_.DistinguishedName -match '^CN=(?:\\.|[^,])+,CN=Computers,DC='
    }

    $defaultContainerCount = ($defaultContainerComputers | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $defaultContainerCount -eq 0

    # Generate markdown results
    if ($totalCount -gt 0) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($defaultContainerCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Computers | $totalCount |" + "`n"
        $result += "| Enabled Computers | $enabledCount |" + "`n"
        $result += "| In Default Computers Container | $defaultContainerCount |" + "`n"
        $result += "| Default Container Percentage | $percentage% |" + "`n" + "`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $defaultContainerCount out of $enabledCount enabled computers ($percentage%) are located in the default Computers container.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. No enabled computers are in the default Computers container.`n`n$result"
    } else {
        $testResultMarkdown = "Enabled computers remain in the default Computers container. Move them to managed OUs so intended Group Policy applies.`n`n$result"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
