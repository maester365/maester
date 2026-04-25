function Test-MtAdTrustInterForestCount {
    <#
    .SYNOPSIS
    Counts the number of inter-forest trusts in Active Directory.

    .DESCRIPTION
    This test retrieves the count of inter-forest (external) trusts configured in Active Directory.
    Inter-forest trusts connect different Active Directory forests and have different security
    implications than intra-forest trusts. These trusts may be less secure and require careful monitoring.

    .EXAMPLE
    Test-MtAdTrustInterForestCount

    Returns $true if trust data is accessible, $false otherwise.
    The test result includes the count of inter-forest trusts.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdTrustInterForestCount
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

    # Count inter-forest trusts
    $interForestTrusts = $trusts | Where-Object { $_.IntraForest -eq $false }
    $interForestCount = ($interForestTrusts | Measure-Object).Count
    $totalCount = ($trusts | Measure-Object).Count

    # Test passes if we successfully retrieved trust data
    $testResult = $true

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Trusts | $totalCount |`n"
    $result += "| Inter-Forest Trusts | $interForestCount |`n"
    $result += "| Intra-Forest Trusts | $($totalCount - $interForestCount) |`n`n"

    if ($interForestCount -eq 0) {
        $testResultMarkdown = "No inter-forest trusts are configured. All trusts (if any) are within the same forest.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "There are $interForestCount inter-forest trust(s) configured. Inter-forest trusts connect to external forests and should be carefully monitored for security.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
