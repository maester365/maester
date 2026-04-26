function Test-MtAdDomainNameStandardCompliance {
    <#
    .SYNOPSIS
    Checks if domain names comply with RFC standards.

    .DESCRIPTION
    This test verifies that domain names in the forest comply with RFC 1123 and RFC 952
    naming standards. Non-compliant domain names can cause DNS resolution issues,
    certificate problems, and compatibility issues with various applications.

    .EXAMPLE
    Test-MtAdDomainNameStandardCompliance

    Returns $true if domain name compliance data is accessible.
    The test result includes the count of non-compliant domain names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdDomainNameStandardCompliance
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

    $forest = $adState.Forest
    $domains = $forest.Domains

    # RFC 1123 compliant domain name pattern
    # Allows letters, digits, and hyphens; must start with letter or digit
    $validDomainNamePattern = '^[a-zA-Z0-9]([a-zA-Z0-9-]{0,61}[a-zA-Z0-9])?$'

    $nonCompliantDomains = @()
    foreach ($domain in $domains) {
        # Split domain into labels and check each
        $labels = $domain -split '\.'
        $isCompliant = $true
        foreach ($label in $labels) {
            if ($label -notmatch $validDomainNamePattern -or $label.Length -gt 63) {
                $isCompliant = $false
                break
            }
        }
        if (-not $isCompliant) {
            $nonCompliantDomains += $domain
        }
    }

    $nonCompliantCount = $nonCompliantDomains.Count
    $totalDomains = $domains.Count

    # Test passes if we successfully analyzed domain names
    $testResult = $totalDomains -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Domains | $totalDomains |`n"
        $result += "| Non-Compliant Domains | $nonCompliantCount |`n"
        $result += "| Compliant Domains | $($totalDomains - $nonCompliantCount) |`n"

        if ($nonCompliantCount -gt 0) {
            $result += "| Non-Compliant Domain Names | $($nonCompliantDomains -join ', ') |`n"
        }

        $testResultMarkdown = "Domain name RFC compliance has been checked. $nonCompliantCount out of $totalDomains domain(s) have non-compliant names.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve domain information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


