function Test-MtAdTrustTotalCount {
    <#
    .SYNOPSIS
    Counts the total number of Active Directory trusts.

    .DESCRIPTION
    This test retrieves the total count of domain trusts configured in Active Directory.
    Domain trusts allow authentication and resource access between domains, and knowing
    the number of trusts is essential for security assessment and trust relationship management.

    .EXAMPLE
    Test-MtAdTrustTotalCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the total count of trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustTotalCount
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

    $trusts = $adState.Trusts

    # Count total trusts
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n`n"

    if ($totalCount -eq 0) {
        $testResultMarkdown = "No Active Directory trusts are configured in this domain. This is typical for single-domain environments.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "Active Directory trust relationships have been analyzed. There are $totalCount trust(s) configured in this domain.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
