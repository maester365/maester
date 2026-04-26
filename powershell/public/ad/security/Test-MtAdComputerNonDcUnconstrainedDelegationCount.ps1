function Test-MtAdComputerNonDcUnconstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts non-domain controller computers with unconstrained delegation.

    .DESCRIPTION
    Non-DC computers with unconstrained delegation represent a significant security risk.
    While domain controllers may require unconstrained delegation for certain scenarios,
    regular computers should never have this configuration. This test specifically
    identifies non-DC computers with unconstrained delegation enabled.

    Security Risk:
    - Non-DC computers with unconstrained delegation are a critical vulnerability
    - Compromise of such a computer allows attackers to impersonate any domain user
    - This configuration should be eliminated in favor of constrained delegation
    - Zero non-DC computers should have unconstrained delegation

    .EXAMPLE
    Test-MtAdComputerNonDcUnconstrainedDelegationCount

    Returns $true if no non-DC computers have unconstrained delegation (or if data is accessible).

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerNonDcUnconstrainedDelegationCount
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

    # Get list of DC names
    $dcNames = $domainControllers | ForEach-Object { $_.Name }

    # Find non-DC computers with unconstrained delegation
    $nonDcComputers = $computers | Where-Object { $dcNames -notcontains $_.Name }
    $nonDcUnconstrained = $nonDcComputers | Where-Object { $_.TrustedForDelegation -eq $true }
    $nonDcUnconstrainedCount = ($nonDcUnconstrained | Measure-Object).Count

    $totalNonDcComputers = ($nonDcComputers | Measure-Object).Count

    # Test passes if no non-DC computers have unconstrained delegation
    $testResult = ($nonDcUnconstrainedCount -eq 0)

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Non-DC Computers | $totalNonDcComputers |`n"
    $result += "| Non-DC Computers with Unconstrained Delegation | $nonDcUnconstrainedCount |`n"
    $result += "| Status | $(if ($testResult) { 'PASS - No non-DC computers with unconstrained delegation' } else { 'FAIL - Non-DC computers have unconstrained delegation' }) |`n"

    if ($nonDcUnconstrainedCount -gt 0) {
        $result += "`n**Non-DC Computers with Unconstrained Delegation:**`n`n"
        $result += "| Computer Name | Operating System |`n"
        $result += "| --- | --- |`n"
        foreach ($comp in $nonDcUnconstrained | Select-Object -First 10) {
            $result += "| $($comp.Name) | $($comp.operatingSystem) |`n"
        }
        if ($nonDcUnconstrainedCount -gt 10) {
            $result += "| ... and $($nonDcUnconstrainedCount - 10) more | |`n"
        }
    }

    $testResultMarkdown = "Non-DC computers with unconstrained delegation represent a critical security risk and should be eliminated.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


