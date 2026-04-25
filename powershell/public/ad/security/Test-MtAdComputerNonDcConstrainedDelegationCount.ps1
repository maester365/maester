function Test-MtAdComputerNonDcConstrainedDelegationCount {
    <#
    .SYNOPSIS
    Counts non-domain controller computers with constrained delegation configured.

    .DESCRIPTION
    Constrained delegation (also known as "protocol transition" or "S4U2Proxy")
    allows a service to impersonate a user to specific services only. While safer
    than unconstrained delegation, it should still be carefully reviewed and minimized.
    This test identifies non-DC computers with constrained delegation enabled.

    Security Considerations:
    - Constrained delegation is safer than unconstrained but still carries risk
    - Should be limited to specific required scenarios (e.g., web applications)
    - Each computer with constrained delegation should be reviewed
    - Consider using resource-based constrained delegation as a more secure alternative

    .EXAMPLE
    Test-MtAdComputerNonDcConstrainedDelegationCount

    Returns $true if computer data is accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerNonDcConstrainedDelegationCount
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

    # Find non-DC computers with constrained delegation
    $nonDcComputers = $computers | Where-Object { $dcNames -notcontains $_.Name }
    $nonDcConstrained = $nonDcComputers | Where-Object { $_.TrustedToAuthForDelegation -eq $true }
    $nonDcConstrainedCount = ($nonDcConstrained | Measure-Object).Count

    # Also check for computers with both types of delegation
    $nonDcBoth = $nonDcComputers | Where-Object { $_.TrustedToAuthForDelegation -eq $true -and $_.TrustedForDelegation -eq $true }
    $nonDcBothCount = ($nonDcBoth | Measure-Object).Count

    $totalNonDcComputers = ($nonDcComputers | Measure-Object).Count
    $testResult = $true

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total Non-DC Computers | $totalNonDcComputers |`n"
    $result += "| Non-DC Computers with Constrained Delegation | $nonDcConstrainedCount |`n"
    $result += "| Non-DC Computers with Both Delegation Types | $nonDcBothCount |`n"

    if ($nonDcConstrainedCount -gt 0) {
        $percentage = [Math]::Round(($nonDcConstrainedCount / $totalNonDcComputers) * 100, 2)
        $result += "| Percentage with Constrained Delegation | $percentage% |`n"
    }

    if ($nonDcConstrainedCount -gt 0) {
        $result += "`n**Non-DC Computers with Constrained Delegation:**`n`n"
        $result += "| Computer Name | Operating System |`n"
        $result += "| --- | --- |`n"
        foreach ($comp in $nonDcConstrained | Select-Object -First 10) {
            $result += "| $($comp.Name) | $($comp.operatingSystem) |`n"
        }
        if ($nonDcConstrainedCount -gt 10) {
            $result += "| ... and $($nonDcConstrainedCount - 10) more | |`n"
        }
    }

    $testResultMarkdown = "Non-DC computers with constrained delegation have been identified. These should be reviewed to ensure they are necessary and properly configured.`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
