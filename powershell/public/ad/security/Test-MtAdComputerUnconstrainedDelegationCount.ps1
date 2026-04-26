function Test-MtAdComputerUnconstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts computers with unconstrained delegation configured.

    .DESCRIPTION
    Unconstrained delegation allows a service to impersonate a user to any other service.
    This is a high-risk configuration that should be minimized. This test counts all
    computers (including domain controllers) that have unconstrained delegation enabled.

    Security Risk:
    - Unconstrained delegation allows full impersonation of authenticated users
    - If a computer with unconstrained delegation is compromised, attackers can
      impersonate any user who authenticates to that computer
    - Should be replaced with constrained or resource-based constrained delegation

    .EXAMPLE
    Test-MtAdComputerUnconstrainedDelegationCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerUnconstrainedDelegationCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState

    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $computers = $adState.Computers
    $domainControllers = $adState.DomainControllers

    # Get list of DC names for reference
    $dcNames = $domainControllers | ForEach-Object { $_.Name }

    # Find computers with unconstrained delegation
    $unconstrainedComputers = $computers | Where-Object { $_.TrustedForDelegation -eq $true }
    $unconstrainedCount = ($unconstrainedComputers | Measure-Object).Count

    # Count DCs vs non-DCs with unconstrained delegation
    $dcUnconstrainedCount = ($unconstrainedComputers | Where-Object { $dcNames -contains $_.Name } | Measure-Object).Count
    $nonDcUnconstrainedCount = $unconstrainedCount - $dcUnconstrainedCount

    $totalComputers = ($computers | Measure-Object).Count
    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Computers | $totalComputers |`n"
    $result += "| Computers with Unconstrained Delegation | $unconstrainedCount |`n"
    $result += "| Domain Controllers with Unconstrained Delegation | $dcUnconstrainedCount |`n"
    $result += "| Non-DC Computers with Unconstrained Delegation | $nonDcUnconstrainedCount |`n"

    if ($unconstrainedCount -gt 0) {
        $percentage = [Math]::Round(($unconstrainedCount / $totalComputers) * 100, 2)
        $result += "| Percentage with Unconstrained Delegation | $percentage% |`n"
    }

    $testResultMarkdown = "Computers with unconstrained delegation have been identified. This configuration allows services to impersonate users to any service.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


