function Test-MtAdDomainFunctionalLevel {
    <#
    .SYNOPSIS
    Retrieves the current domain functional level.

    .DESCRIPTION
    This test retrieves the current domain functional level which indicates the
    features and capabilities available in the Active Directory domain. Higher
    functional levels enable advanced security features and should be used when possible.

    .EXAMPLE
    Test-MtAdDomainFunctionalLevel

    Returns $true if domain functional level data is accessible.
    The test result includes the current domain functional level.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDomainFunctionalLevel
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

    $domain = $adState.Domain
    $functionalLevel = $domain.DomainMode

    # Test passes if we successfully retrieved domain data
    $testResult = $null -ne $functionalLevel

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Domain Functional Level | $functionalLevel |`n"
        $result += "| Domain Name | $($domain.Name) |`n"
        $result += "| Domain SID | $($domain.DomainSID) |`n"

        $testResultMarkdown = "The Active Directory domain functional level has been retrieved successfully.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory domain functional level. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
