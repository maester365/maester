function Test-MtAdIntermediateCaDetails {
    <#
    .SYNOPSIS
    Retrieves detailed information about intermediate certificate authorities.

    .DESCRIPTION
    This test retrieves detailed information about intermediate CAs from the AIA container
    in Active Directory, including certificate validity information.

    .EXAMPLE
    Test-MtAdIntermediateCaDetails

    Returns $true if intermediate CA details are accessible, $false otherwise.
    The test result includes details of each intermediate CA.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdIntermediateCaDetails
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

    $config = $adState.Configuration
    $intermediateCAs = $config.IntermediateCAs
    $caCount = ($intermediateCAs | Measure-Object).Count

    # Test passes if we successfully retrieved the data
    $testResult = $null -ne $intermediateCAs

    # Generate markdown results
    if ($testResult) {
        $result = "| Intermediate CA | Certificate Present |`n"
        $result += "| --- | --- |`n"

        foreach ($ca in $intermediateCAs | Select-Object -First 10) {
            $caName = $ca.Name
            $hasCert = if ($ca.cACertificate) { "Yes" } else { "No" }
            $result += "| $caName | $hasCert |`n"
        }

        if ($caCount -gt 10) {
            $result += "| ... ($($caCount - 10) more) | ... |`n"
        }

        $testResultMarkdown = "Active Directory intermediate CA details have been analyzed. $caCount intermediate CA(s) found.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve intermediate CA details from Active Directory. Ensure you have appropriate permissions."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
