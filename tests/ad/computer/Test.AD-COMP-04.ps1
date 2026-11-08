function Test-MtAdComputerNonStandardGroup {
    <#
    .SYNOPSIS
    Counts computers with non-standard primary group IDs.

    .DESCRIPTION
    This test identifies computer objects that are not using standard primary group IDs.
    Standard computer primary groups are:
    - 515: Domain Computers
    - 516: Domain Controllers
    - 521: Read-only Domain Controllers

    Computers with non-standard primary groups may indicate misconfiguration or
    custom security configurations that should be reviewed.

    .EXAMPLE
    Test-MtAdComputerNonStandardGroup

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of computers with non-standard primary groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerNonStandardGroup
    #>
    [MaesterTest(
        Id = 'AD-COMP-04',
        Title = 'Enabled computers should use standard primary groups',
        Product = 'ad',
        Feature = 'computers',
        Area = 'identity-lifecycle',
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

    Write-Verbose "Starting Test-MtAdComputerNonStandardGroup"

    # Standard computer primary group IDs
    $standardGroupIds = @(515, 516, 521)

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Computers')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState -or $null -eq $adState.Computers) { throw 'Computer inventory is required to assess primary groups.' }

    $computers = $adState.Computers
    if (@($computers).Count -eq 0) { throw 'Computer inventory is empty; primary groups cannot be assessed.' }
    if (@($computers | Where-Object { $null -eq $_.Enabled }).Count -gt 0) {
        throw 'Enabled state is missing for computers; primary groups cannot be assessed completely.'
    }

    # Count enabled computers with non-standard primary group
    $nonStandardGroupComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $null -ne $_.primaryGroupId -and
        $_.primaryGroupId -notin $standardGroupIds
    }

    $nonStandardCount = ($nonStandardGroupComputers | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    if (@($computers | Where-Object { $_.Enabled -eq $true -and $null -eq $_.PrimaryGroupId }).Count -gt 0) {
        throw 'PrimaryGroupId is missing for enabled computers; cannot assess all primary groups.'
    }
    $testResult = $nonStandardCount -eq 0

    # Generate markdown results
    if ($totalCount -gt 0) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($nonStandardCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Computers | $totalCount |" + "`n"
        $result += "| Enabled Computers | $enabledCount |" + "`n"
        $result += "| Non-Standard Primary Group | $nonStandardCount |" + "`n"
        $result += "| Non-Standard Percentage | $percentage% |" + "`n" + "`n"
        $result += "**Standard Primary Group IDs:** 515 (Domain Computers), 516 (Domain Controllers), 521 (Read-only Domain Controllers)" + "`n" + "`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $nonStandardCount out of $enabledCount enabled computers ($percentage%) have non-standard primary group IDs.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    if ($testResult) {
        $testResultMarkdown = "Well done. No enabled computers have a non-standard primary group.`n`n$result"
    } else {
        $testResultMarkdown = "Enabled computers have non-standard primary groups. Review and restore standard group assignments where appropriate.`n`n$result"
    }
    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
