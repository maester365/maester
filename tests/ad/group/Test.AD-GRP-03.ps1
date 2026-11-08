function Test-MtAdGroupStaleCount {
    <#
    .SYNOPSIS
    Checks whether groups have been modified within a configurable number of days.

    .DESCRIPTION
    This test identifies groups that have not been modified since before January 1, 2020.
    Groups that haven't been modified for an extended period may represent:
    - Unused or obsolete groups that should be reviewed for deletion
    - Legacy configurations that may no longer be needed
    - Potential security risks from forgotten or undocumented group memberships

    .EXAMPLE
    Test-MtAdGroupStaleCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of stale groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupStaleCount
    #>
    [MaesterTest(
        Id = 'AD-GRP-03',
        Title = 'Groups should be modified within the configured age',
        Product = 'ad',
        Feature = 'groups',
        Area = 'identity-lifecycle',
        ResourceType = 'Group',
        Severity = 'Low',
        UserImpact = 'Low',
        ImplementationCost = 'Medium',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:group:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Maximum number of days since a group's last modification.
        [ValidateRange(1, 36500)]
        [int] $MaximumAgeDays = 365
    )

    Write-Verbose "Starting Test-MtAdGroupStaleCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Groups')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $groups = $adState.Groups

    if ($null -eq $adState.Groups) { throw 'Group collection is unavailable.' }
    # Modification age is a hygiene indicator, not proof of actual group usage.
    $cutoffDate = (Get-Date).AddDays(-$MaximumAgeDays)
    $staleGroups = $groups | Where-Object {
        $_.modifyTimeStamp -and $_.modifyTimeStamp -lt $cutoffDate
    }

    $staleCount = ($staleGroups | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0 -and $staleCount -eq 0

    # Generate markdown results
    if ($totalCount -gt 0) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($staleCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Groups | $totalCount |" + "`n"
        $result += "| Groups Modified Before Cutoff | $staleCount |" + "`n"
        $result += "| Stale Percentage | $percentage% |" + "`n"
        $result += "| Cutoff Date | $($cutoffDate.ToString('yyyy-MM-dd')) |" + "`n" + "`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $staleCount out of $totalCount groups ($percentage%) have not been modified within $MaximumAgeDays days.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
