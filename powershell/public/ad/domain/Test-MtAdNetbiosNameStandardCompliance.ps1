function Test-MtAdNetbiosNameStandardCompliance {
    <#
    .SYNOPSIS
    Checks if NetBIOS names comply with naming standards.

    .DESCRIPTION
    This test verifies that NetBIOS names in the forest comply with standard naming
    conventions. Non-compliant NetBIOS names can cause issues with legacy applications,
    WINS resolution, and some network services.

    .EXAMPLE
    Test-MtAdNetbiosNameStandardCompliance

    Returns $true if NetBIOS name compliance data is accessible.
    The test result includes the count of non-compliant NetBIOS names.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdNetbiosNameStandardCompliance
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
    
    # Collect NetBIOS names from domain and forest
    $netbiosNames = @()
    if ($domain.NetBIOSName) {
        $netbiosNames += $domain.NetBIOSName
    }

    # NetBIOS name pattern: 1-15 chars, alphanumeric and some special chars
    # Should not contain: \ / : * ? " < > |
    $validNetbiosPattern = '^[A-Za-z0-9!@#$%^&''()\-_\.+\{\}~]{1,15}$'

    $nonCompliantNames = @()
    foreach ($name in $netbiosNames) {
        if ($name -notmatch $validNetbiosPattern) {
            $nonCompliantNames += $name
        }
    }

    $nonCompliantCount = $nonCompliantNames.Count
    $totalNames = $netbiosNames.Count

    # Test passes if we successfully analyzed NetBIOS names
    $testResult = $totalNames -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total NetBIOS Names | $totalNames |`n"
        $result += "| Non-Compliant Names | $nonCompliantCount |`n"
        $result += "| Compliant Names | $($totalNames - $nonCompliantCount) |`n"

        if ($nonCompliantCount -gt 0) {
            $result += "| Non-Compliant Names | $($nonCompliantNames -join ', ') |`n"
        }

        $testResultMarkdown = "NetBIOS name compliance has been checked. $nonCompliantCount out of $totalNames NetBIOS name(s) are non-compliant.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve NetBIOS name information. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}

