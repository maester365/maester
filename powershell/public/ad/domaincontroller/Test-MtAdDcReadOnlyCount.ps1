function Test-MtAdDcReadOnlyCount {
    <#
    .SYNOPSIS
    Counts read-only domain controllers (RODCs) in the domain.

    .DESCRIPTION
    This test identifies the number of read-only domain controllers (RODCs) in the Active Directory domain.
    RODCs are designed for deployment in locations where physical security cannot be guaranteed,
    such as branch offices. They maintain a read-only copy of the Active Directory database
    and can help reduce security risks in less secure locations.

    .EXAMPLE
    Test-MtAdDcReadOnlyCount

    Returns $true if DC data is accessible.
    The test result includes the count of RODCs and writable DCs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDcReadOnlyCount
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

    $domainControllers = $adState.DomainControllers
    $dcCount = ($domainControllers | Measure-Object).Count

    # Count RODCs vs writable DCs
    $rodcs = $domainControllers | Where-Object { $_.IsReadOnly -eq $true }
    $rodcCount = ($rodcs | Measure-Object).Count
    $writableDcCount = $dcCount - $rodcCount

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -gt 0

    # Generate markdown results
    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Domain Controllers | $dcCount |`n"
    $result += "| Writable Domain Controllers | $writableDcCount |`n"
    $result += "| Read-Only Domain Controllers (RODC) | $rodcCount |`n"

    if ($rodcCount -gt 0) {
        $result += "| RODC Names | $($rodcs.Name -join ', ') |`n"
        $result += "| RODC Sites | $($rodcs.Site -join ', ') |`n"
        $testResultMarkdown = "ℹ️ **RODC Configuration**: $rodcCount read-only domain controller(s) detected. RODCs are appropriate for branch office deployments where physical security cannot be guaranteed.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "ℹ️ **No RODCs**: All $dcCount domain controller(s) are writable DCs. Consider RODCs for branch office locations with limited physical security.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}



