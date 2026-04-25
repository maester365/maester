function Test-MtAdAllowedDnsSuffixesCount {
    <#
    .SYNOPSIS
    Retrieves the count of allowed DNS suffixes configured for the domain.

    .DESCRIPTION
    This test retrieves the count of allowed DNS suffixes configured in the Active Directory domain.
    Allowed DNS suffixes define which DNS domain suffixes can be used when joining computers to the domain.
    This configuration helps maintain DNS namespace consistency and prevents unauthorized domain joins
    from external or untrusted DNS namespaces.

    .EXAMPLE
    Test-MtAdAllowedDnsSuffixesCount

    Returns $true if allowed DNS suffix data is accessible.
    The test result includes the count of configured allowed DNS suffixes.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdAllowedDnsSuffixesCount
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
    $allowedDnsSuffixes = $domain.AllowedDnsSuffixes
    $suffixCount = ($allowedDnsSuffixes | Measure-Object).Count

    # Test passes if we successfully retrieved domain data
    $testResult = $null -ne $allowedDnsSuffixes

    # Generate markdown results
    if ($testResult) {
        $result = "| Property | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Allowed DNS Suffix Count | $suffixCount |`n"
        $result += "| Domain Name | $($domain.Name) |`n"
        $result += "| Domain DNS Root | $($domain.DNSRoot) |`n"

        if ($suffixCount -gt 0) {
            $result += "| Allowed DNS Suffixes | $($allowedDnsSuffixes -join ', ') |`n"
            $result += "`n**Note:** Allowed DNS suffixes are configured. Only computers with these DNS suffixes can join the domain.`n"
        } else {
            $result += "| Allowed DNS Suffixes | (none configured - any DNS suffix allowed) |`n"
            $result += "`n**Note:** No allowed DNS suffixes are configured. Computers with any DNS suffix can join the domain.`n"
        }

        $testResultMarkdown = "The Active Directory domain allowed DNS suffixes have been analyzed successfully.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory allowed DNS suffix information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
