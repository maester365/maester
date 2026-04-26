function Test-MtAdGroupDistributionCount {
    <#
    .SYNOPSIS
    Counts the number of distribution groups in Active Directory.

    .DESCRIPTION
    This test counts distribution groups in Active Directory, which are email-only groups
    used for Exchange and email distribution. Unlike security groups, distribution groups
    cannot be used for access control. This test provides visibility into the email
    distribution infrastructure and helps distinguish email-only groups from security groups.

    .EXAMPLE
    Test-MtAdGroupDistributionCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes counts of distribution groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupDistributionCount
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

    # Count distribution groups (GroupCategory = "Distribution")
    $distributionGroups = $groups | Where-Object { $_.GroupCategory -eq "Distribution" }
    $distributionCount = ($distributionGroups | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($distributionCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Distribution Groups | $distributionCount |`n"
        $result += "| Distribution Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory group objects have been analyzed. $distributionCount out of $totalCount groups ($percentage%) are distribution groups (email-only).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


