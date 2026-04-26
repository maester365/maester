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

    # Count enabled computers with CreatorSid attribute
    # Note: CreatorSid is not a default property from Get-ADComputer, so we check if it exists
    $computersWithCreatorSid = $computers | Where-Object {
        $_.Enabled -eq $true -and
        $_.PSObject.Properties['ms-ds-CreatorSid'] -and
        $_.'ms-ds-CreatorSid'
    }

    $creatorSidCount = ($computersWithCreatorSid | Measure-Object).Count
    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($enabledCount -gt 0) {
            [Math]::Round(($creatorSidCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Computers with CreatorSid | $creatorSidCount |`n"
        $result += "| CreatorSid Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $creatorSidCount out of $enabledCount enabled computers ($percentage%) have the CreatorSid attribute set.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


