function Test-MtAdGroupInContainerCount {
    <#
    .SYNOPSIS
    Counts groups located in container objects (CN=) instead of Organizational Units (OU=).

    .DESCRIPTION
    This test examines each group's immediate parent distinguished-name component,
    not the CN component naming the group itself. OUs can support consistent
    organization and delegated administration. Group objects do not receive GPO
    settings; group membership may instead be used for security filtering.

    .EXAMPLE
    Test-MtAdGroupInContainerCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of groups in container objects.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupInContainerCount
    #>
    [MaesterTest(
        Id = 'AD-GRP-02',
        Title = 'Groups in container objects count should be retrievable',
        Product = 'ad',
        Feature = 'groups',
        Area = 'infrastructure',
        ResourceType = 'Group',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:group:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGroupInContainerCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Groups')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Active Directory inventory is unavailable; the declared service gate is handled by the engine.'
        return $null
    }

    $groups = $adState.Groups
    if ($null -eq $groups) { throw 'Group inventory is unavailable; parent locations cannot be assessed.' }
    if (@($groups | Where-Object { [string]::IsNullOrWhiteSpace($_.DistinguishedName) }).Count -gt 0) {
        throw 'Group distinguished names are unavailable; parent locations cannot be assessed.'
    }

    # Count groups in containers (CN=) vs OUs (OU=)
    $groupsInContainers = $groups | Where-Object {
        ($_.DistinguishedName -replace '^(?:\\.|[^,])+,', '') -match '^CN='
    }

    $containerCount = ($groupsInContainers | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count
    $ouCount = @($groups | Where-Object { ($_.DistinguishedName -replace '^(?:\\.|[^,])+,', '') -match '^OU=' }).Count
    $otherCount = $totalCount - $containerCount - $ouCount

    # Test passes if we successfully retrieved group data
    $testResult = $null -ne $adState.Groups

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($containerCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Groups | $totalCount |" + "`n"
        $result += "| Groups in OUs (OU=) | $ouCount |" + "`n"
        $result += "| Groups in Containers (CN=) | $containerCount |" + "`n"
        $result += "| Groups with Other Parent Types | $otherCount |" + "`n"
        $result += "| Container Percentage | $percentage% |" + "`n" + "`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $containerCount out of $totalCount groups ($percentage%) are located in container objects (CN=) rather than Organizational Units.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
