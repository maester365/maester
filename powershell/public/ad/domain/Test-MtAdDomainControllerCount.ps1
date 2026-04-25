function Test-MtAdDomainControllerCount {
    <#
    .SYNOPSIS
    Counts the number of domain controllers in the domain.

    .DESCRIPTION
    This test retrieves the count of domain controllers in the Active Directory domain.
    Knowing your DC count is essential for capacity planning, disaster recovery, and
    ensuring proper redundancy for authentication services.

    .EXAMPLE
    Test-MtAdDomainControllerCount

    Returns $true if domain controller data is accessible.
    The test result includes the count of domain controllers.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDomainControllerCount
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

    # Test passes if we successfully retrieved DC data
    $testResult = $dcCount -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Domain Controllers | $dcCount |`n"
        $result += "| Domain | $($adState.Domain.Name) |`n"

        if ($dcCount -gt 0) {
            $dcNames = $domainControllers | ForEach-Object { $_.Name } | Sort-Object
            $result += "| DC Names | $($dcNames -join ', ') |`n"
        }

        $testResultMarkdown = "Active Directory domain controllers have been counted. There are $dcCount domain controller(s) in the domain.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve domain controller information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
