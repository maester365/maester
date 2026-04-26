function Test-MtAdComputerDelegationCount {
    <#
    .SYNOPSIS
    Counts computers with delegation configured.

    .DESCRIPTION
    This test identifies computer objects that have Kerberos delegation configured.
    Delegation allows a service to impersonate users when accessing resources, which
    can be a security risk if not properly configured. This test counts:
    - Unconstrained delegation (most risky)
    - Constrained delegation
    - Protocol transition delegation

    .EXAMPLE
    Test-MtAdComputerDelegationCount

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes the count of computers with various delegation types.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDelegationCount
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

    # Count computers with different delegation types
    $unconstrainedDelegation = $computers | Where-Object {
        $_.TrustedForDelegation -eq $true
    }

    $constrainedDelegation = $computers | Where-Object {
        $_.TrustedToAuthForDelegation -eq $true
    }

    $unconstrainedCount = ($unconstrainedDelegation | Measure-Object).Count
    $constrainedCount = ($constrainedDelegation | Measure-Object).Count
    $totalDelegationCount = $unconstrainedCount + $constrainedCount

    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $delegationPercentage = if ($enabledCount -gt 0) {
            [Math]::Round(($totalDelegationCount / $enabledCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Computers with Any Delegation | $totalDelegationCount |`n"
        $result += "| Unconstrained Delegation | $unconstrainedCount |`n"
        $result += "| Constrained/Protocol Transition | $constrainedCount |`n"
        $result += "| Delegation Percentage | $delegationPercentage% |`n`n"

        $testResultMarkdown = "Active Directory computer objects have been analyzed. $totalDelegationCount out of $enabledCount enabled computers ($delegationPercentage%) have delegation configured.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


