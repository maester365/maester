function Test-MtAdComputerDisabledCount {
    <#
    .SYNOPSIS
    Counts the number of disabled computer objects in Active Directory.

    .DESCRIPTION
    This investigation inventory counts known enabled, known disabled and unknown-state
    computers, reports the disabled share of the visible inventory, and lists disabled
    objects for lifecycle review. It does not impose a zero-disabled-account baseline.

    .EXAMPLE
    Invoke-MtTest -Id AD-COMP-01

    Inventories visible computer account states and reports Investigate.
    Missing required inventory produces Error rather than a security failure.

    .LINK
    https://maester.dev/docs/tests/AD-COMP-01
    #>
    [MaesterTest(
        Id = 'AD-COMP-01',
        Title = 'Computer disabled count should be retrievable',
        Product = 'ad',
        Feature = 'computers',
        Area = 'identity-lifecycle',
        ResourceType = 'Computer',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:computer:ReadProperty'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdComputerDisabledCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Computers')

    if ($null -eq $adState -or $null -eq $adState.Computers) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'Computer inventory is unavailable; disabled accounts cannot be assessed.'
        return $null
    }

    $computers = $adState.Computers

    # Count disabled and total computers
    $disabledComputers = $computers | Where-Object { $_.Enabled -eq $false }
    $disabledCount = ($disabledComputers | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count
    $enabledCount = @($computers | Where-Object { $_.Enabled -eq $true }).Count
    $unknownCount = @($computers | Where-Object { $null -eq $_.Enabled }).Count

    $testResult = $null -ne $adState.Computers

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($disabledCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Computers | $totalCount |" + "`n"
        $result += "| Enabled Computers | $enabledCount |" + "`n"
        $result += "| Disabled Computers | $disabledCount |" + "`n"
        $result += "| Computers with Unknown Enabled State | $unknownCount |" + "`n"
        $result += "| Disabled Percentage | $percentage% |" + "`n" + "`n"
        $result += "| Disabled Computer | Distinguished Name |`n| --- | --- |`n"
        foreach ($computer in $disabledComputers) {
            $result += '| {0} | {1} |' -f (Format-MtAdSiteInventoryValue $computer.Name), (Format-MtAdSiteInventoryValue $computer.DistinguishedName)
            $result += "`n"
        }

        $testResultMarkdown = "ℹ️ Review the disabled-computer lifecycle inventory. $disabledCount of $totalCount visible computers ($percentage%) are known disabled. $unknownCount have unknown enabled state, so the reported disabled share may undercount disabled objects. Disabled accounts may be intentional; this is not a security pass/fail threshold.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
