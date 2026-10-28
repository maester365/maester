function Test-MtAdComputerDormantCount {
    <#
    .SYNOPSIS
    Counts the number of dormant computer objects in Active Directory.

    .DESCRIPTION
    This test identifies computer objects that have not logged on for more than the configured threshold.
    Dormant computers can represent security risks if they are still enabled and can be
    used for unauthorized access. This test provides visibility into stale computer accounts.

    .EXAMPLE
    Test-MtAdComputerDormantCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes counts of dormant computers since the configured threshold.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDormantCount
    #>
    [MaesterTest(
        Id = 'AD-COMP-02',
        Title = 'Computer dormant count should be retrievable',
        Product = 'ad',
        Feature = 'computers',
        Area = 'identity-lifecycle',
        ResourceType = 'Computer',
        Severity = 'Info',
        Mitre = 'T1078.002',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param(
        # Number of days without a logon before an enabled computer is considered dormant.
        [ValidateRange(1, 3650)]
        [int] $DormantThresholdDays = 90
    )

    Write-Verbose "Starting Test-MtAdComputerDormantCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Computers')

    # If unable to retrieve AD data, skip the test
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers
    $thresholdDays = $DormantThresholdDays
    $thresholdDate = (Get-Date).AddDays(-$thresholdDays)

    # Count dormant computers (last logon older than the configured threshold and still enabled)
    $dormantComputers = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.lastLogonDate -and
        $_.lastLogonDate -lt $thresholdDate
    }

    $dormantCount = ($dormantComputers | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($dormantCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Computers | $totalCount |" + "`n"
        $result += "| Enabled Computers | $enabledCount |" + "`n"
        $result += "| Dormant Computers (>$thresholdDays days) | $dormantCount |" + "`n"
        $result += "| Dormant Percentage (of enabled) | $percentage% |" + "`n" + "`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $dormantCount out of $enabledCount enabled computers ($percentage%) have not logged on for more than $thresholdDays days.`n`n%TestResult%"
        if ($dormantCount -eq 0) {
            $datedEnabledComputers = $computers | Where-Object { $_.Enabled -eq $true -and $null -ne $_.lastLogonDate }
            $undatedEnabledCount = $enabledCount - $datedEnabledComputers.Count
            $oldestLastLogonDate = $datedEnabledComputers |
                Sort-Object -Property lastLogonDate |
                Select-Object -First 1 -ExpandProperty lastLogonDate

            if ($null -eq $oldestLastLogonDate) {
                $testResultMarkdown += "`n`nThere are $enabledCount enabled computers. None have a recorded last logon date, so dormant status cannot be determined from available data."
            } else {
                $oldestLastLogonDate = [datetime]$oldestLastLogonDate
                $oldestLastLogon = $oldestLastLogonDate.ToString('yyyy-MM-dd')
                $daysUntilThreshold = [Math]::Max(1, [Math]::Ceiling(($oldestLastLogonDate.AddDays($thresholdDays) - (Get-Date)).TotalDays))
                $undatedNote = if ($undatedEnabledCount -gt 0) { " $undatedEnabledCount enabled computer(s) have no recorded logon date and are not counted in this analysis." } else { "" }
                $testResultMarkdown += "`n`nThere are $enabledCount enabled computers. The oldest last logon date is $oldestLastLogon. No computers currently exceed the dormant threshold of $thresholdDays days. The oldest computer would reach the threshold in $daysUntilThreshold days.$undatedNote"
            }
        }
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
