function Test-MtAdComputerDelegationDetails {
    <#
    .SYNOPSIS
    Provides detailed breakdown of delegation configuration per computer.

    .DESCRIPTION
    This test provides a detailed analysis of Kerberos delegation configuration
    across computer objects in Active Directory. It identifies:
    - Computers with unconstrained delegation (full trust)
    - Computers with constrained delegation (limited to specific services)
    - Computers with protocol transition (S4U2Proxy)

    This detailed view helps security teams identify high-risk delegation
    configurations that may need review or remediation.

    .EXAMPLE
    Test-MtAdComputerDelegationDetails

    Returns $true if computer object data is accessible, $false otherwise.
    The test result includes a detailed breakdown of delegation by computer.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdComputerDelegationDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using Details')]
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

    # Get computers with delegation
    $computersWithUnconstrained = $computers | Where-Object {
        $_.TrustedForDelegation -eq $true
    } | Select-Object Name, DistinguishedName, Enabled, @{N = 'DelegationType'; E = { 'Unconstrained' } }

    $computersWithConstrained = $computers | Where-Object {
        $_.TrustedToAuthForDelegation -eq $true
    } | Select-Object Name, DistinguishedName, Enabled, @{N = 'DelegationType'; E = { 'Constrained/Protocol Transition' } }

    $allDelegationComputers = @($computersWithUnconstrained) + @($computersWithConstrained)

    $unconstrainedCount = ($computersWithUnconstrained | Measure-Object).Count
    $constrainedCount = ($computersWithConstrained | Measure-Object).Count
    $totalDelegationCount = $allDelegationComputers.Count

    $enabledCount = ($computers | Where-Object { $_.Enabled -eq $true } | Measure-Object).Count
    $totalCount = ($computers | Measure-Object).Count

    # Test passes if we successfully retrieved computer data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Computers | $totalCount |`n"
        $result += "| Enabled Computers | $enabledCount |`n"
        $result += "| Computers with Any Delegation | $totalDelegationCount |`n"
        $result += "| Unconstrained Delegation | $unconstrainedCount |`n"
        $result += "| Constrained/Protocol Transition | $constrainedCount |`n`n"

        if ($unconstrainedCount -gt 0) {
            $result += "**Computers with Unconstrained Delegation (High Risk):**`n`n"
            $result += "| Computer Name | Enabled | Distinguished Name |`n"
            $result += "| --- | --- | --- |`n"
            $computersWithUnconstrained | Select-Object -First 20 | ForEach-Object {
                $result += "| $($_.Name) | $($_.Enabled) | $($_.DistinguishedName) |`n"
            }
            if ($unconstrainedCount -gt 20) {
                $result += "| ... | ... | ... ($($unconstrainedCount - 20) more) |`n"
            }
            $result += "`n"
        }

        if ($constrainedCount -gt 0) {
            $result += "**Computers with Constrained Delegation:**`n`n"
            $result += "| Computer Name | Enabled | Distinguished Name |`n"
            $result += "| --- | --- | --- |`n"
            $computersWithConstrained | Select-Object -First 20 | ForEach-Object {
                $result += "| $($_.Name) | $($_.Enabled) | $($_.DistinguishedName) |`n"
            }
            if ($constrainedCount -gt 20) {
                $result += "| ... | ... | ... ($($constrainedCount - 20) more) |`n"
            }
        }

        $testResultMarkdown = "Active Directory computer delegation configuration has been analyzed. $totalDelegationCount computers have delegation configured.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory computer objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


