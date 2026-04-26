function Test-MtAdNetbiosNameNonStandardDetails {
    <#
    .SYNOPSIS
    Lists details of NetBIOS names that don't comply with naming standards.

    .DESCRIPTION
    This test provides detailed information about NetBIOS names that don't comply
    with standard naming conventions. This helps identify specific naming issues
    that may affect legacy applications and network services.

    .EXAMPLE
    Test-MtAdNetbiosNameNonStandardDetails

    Returns $true if NetBIOS name compliance data is accessible.
    The test result includes a list of non-compliant NetBIOS names with details.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdNetbiosNameNonStandardDetails
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

    # Collect NetBIOS names
    $netbiosNames = @()
    if ($domain.NetBIOSName) {
        $netbiosNames += $domain.NetBIOSName
    }

    # NetBIOS name invalid characters
    $invalidChars = @('\\', '/', ':', '*', '?', '"', '<', '>', '|')

    $nonCompliantDetails = @()
    foreach ($name in $netbiosNames) {
        $issues = @()

        if ($name.Length -gt 15) {
            $issues += "Exceeds 15 character limit ($($name.Length) chars)"
        }

        $foundInvalidChars = @()
        foreach ($char in $invalidChars) {
            if ($name.Contains($char)) {
                $foundInvalidChars += $char
            }
        }
        if ($foundInvalidChars.Count -gt 0) {
            $issues += "Contains invalid characters: $($foundInvalidChars -join ', ')"
        }

        if ($issues.Count -gt 0) {
            $nonCompliantDetails += [PSCustomObject]@{
                NetBIOSName = $name
                Length = $name.Length
                Issues = $issues -join '; '
            }
        }
    }

    $nonCompliantCount = $nonCompliantDetails.Count
    $totalNames = $netbiosNames.Count

    # Test passes if we successfully analyzed NetBIOS names
    $testResult = $totalNames -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total NetBIOS Names | $totalNames |`n"
        $result += "| Non-Compliant Names | $nonCompliantCount |`n`n"

        if ($nonCompliantCount -gt 0) {
            $result += "### Non-Compliant NetBIOS Name Details`n`n"
            $result += "| NetBIOS Name | Length | Issues |`n"
            $result += "| --- | --- | --- |`n"
            foreach ($detail in $nonCompliantDetails) {
                $result += "| $($detail.NetBIOSName) | $($detail.Length) | $($detail.Issues) |`n"
            }
        } else {
            $result += "All NetBIOS names comply with naming standards."
        }

        $testResultMarkdown = "NetBIOS name compliance details have been retrieved.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve NetBIOS name information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}

