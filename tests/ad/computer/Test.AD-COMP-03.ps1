function Test-MtAdComputerCreatorSidCount {
    <#
    .SYNOPSIS
    Counts computers with the ms-ds-CreatorSid attribute set.

    .DESCRIPTION
    This test identifies computer objects that have the ms-ds-CreatorSid attribute populated.
    The CreatorSid attribute indicates which security principal created the computer account
    and can be useful for tracking and auditing purposes.

    .EXAMPLE
    Test-MtAdComputerCreatorSidCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of computers with CreatorSid set.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerCreatorSidCount
    #>
    [MaesterTest(
        Id = 'AD-COMP-03',
        Title = 'Computer CreatorSid count should be retrievable',
        Product = 'ad',
        Feature = 'computers',
        Area = 'access-control',
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

    Write-Verbose "Starting Test-MtAdComputerCreatorSidCount"

    # Get AD domain state data (uses cached data if available)
    $adState = Get-MtADDomainState -Categories @('Computers')

    if ($null -eq $adState -or $null -eq $adState.Computers) {
        throw 'Computer inventory is required to review CreatorSid.'
    }

    $computers = $adState.Computers
    if (@($computers | Where-Object { -not $_.PSObject.Properties['mS-DS-CreatorSID'] }).Count -gt 0) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'The cached computer inventory does not expose the mS-DS-CreatorSID LDAP attribute.'
        return
    }

    # Count visible values of the actual LDAP attribute. An absent value does not
    # prove it was never set or distinguish unset data from restricted visibility.
    $computersWithCreatorSid = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.'mS-DS-CreatorSID'
    }

    $creatorSidCount = ($computersWithCreatorSid | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $null -ne $adState.Computers

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($creatorSidCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |" + "`n"
        $result += "| --- | --- |" + "`n"
        $result += "| Total Computers | $totalCount |" + "`n"
        $result += "| Enabled Computers | $enabledCount |" + "`n"
        $result += "| Computers with CreatorSid | $creatorSidCount |" + "`n"
        $result += "| CreatorSid Percentage | $percentage% |" + "`n" + "`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $creatorSidCount out of $enabledCount enabled computers ($percentage%) have a visible mS-DS-CreatorSID value. This inventory does not distinguish an unset value from an unreadable value.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate

    return $testResult
}
