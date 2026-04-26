function Test-MtAdDomainNameNonStandardDetails {
    <#
    .SYNOPSIS
    Lists details of domain names that don't comply with RFC standards.

    .DESCRIPTION
    This test provides detailed information about domain names in the forest that
    don't comply with RFC 1123 and RFC 952 naming standards. This helps identify
    specific domains that may have DNS, certificate, or compatibility issues.

    .EXAMPLE
    Test-MtAdDomainNameNonStandardDetails

    Returns $true if domain name compliance data is accessible.
    The test result includes a list of non-compliant domain names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDomainNameNonStandardDetails
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '', Justification = 'Clarity in using plural')]
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

    $forest = $adState.Forest
    $domains = $forest.Domains

    # RFC 1123 compliant domain name pattern
    $validDomainNamePattern = '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'

    $nonCompliantDomainDetails = @()
    foreach ($domain in $domains) {
        $labels = $domain -split '\.'
        $nonCompliantLabels = @()
        foreach ($label in $labels) {
            if ($label -notmatch $validDomainNamePattern -or $label.Length -gt 63) {
                $nonCompliantLabels += $label
            }
        }
        if ($nonCompliantLabels.Count -gt 0) {
            $nonCompliantDomainDetails += [PSCustomObject]@{
                DomainName         = $domain
                NonCompliantLabels = $nonCompliantLabels -join ', '
                Issue              = "Label(s) don't comply with RFC 1123"
            }
        }
    }

    $nonCompliantCount = $nonCompliantDomainDetails.Count
    $totalDomains = $domains.Count

    # Test passes if we successfully analyzed domain names
    $testResult = $totalDomains -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Domains | $totalDomains |`n"
        $result += "| Non-Compliant Domains | $nonCompliantCount |`n`n"

        if ($nonCompliantCount -gt 0) {
            $result += "### Non-Compliant Domain Details`n`n"
            $result += "| Domain Name | Non-Compliant Labels | Issue |`n"
            $result += "| --- | --- | --- |`n"
            foreach ($detail in $nonCompliantDomainDetails) {
                $result += "| $($detail.DomainName) | $($detail.NonCompliantLabels) | $($detail.Issue) |`n"
            }
        } else {
            $result += "All domain names comply with RFC 1123 standards."
        }

        $testResultMarkdown = "Domain name compliance details have been retrieved.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve domain information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


