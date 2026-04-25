function Test-MtAdGpoDisabledLinkCount {
    <#
    .SYNOPSIS
    Counts the number of disabled GPO links in Active Directory.

    .DESCRIPTION
    This test retrieves the count of disabled GPO links across all organizational units,
    domains, and sites. Disabled links indicate GPOs that are linked but not applied,
    which can create confusion and security gaps if not properly managed.

    .EXAMPLE
    Test-MtAdGpoDisabledLinkCount

    Returns $true if GPO link data is accessible, $false otherwise.
    The test result includes counts of disabled vs total links.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoDisabledLinkCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    # Get AD GPO state data (uses cached data if available)
    $gpoState = Get-MtADGpoState

    # If unable to retrieve GPO data, skip the test
    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpoLinks = $gpoState.GPOLinks

    # Parse gPLink attribute to count disabled links
    # gPLink format: [LDAP://cn={guid},cn=policies,cn=system,DC=domain,DC=com;0]
    # The number after the semicolon indicates: 0=enabled, 1=disabled, 2=enforced
    $totalLinks = 0
    $disabledLinks = 0
    $enabledLinks = 0
    $enforcedLinks = 0

    foreach ($link in $gpoLinks) {
        if ($link.gPLink) {
            # Split by brackets to get individual links
            $linkEntries = $link.gPLink -split '\]' | Where-Object { $_ -match 'LDAP://' }
            foreach ($entry in $linkEntries) {
                $totalLinks++
                # Check the suffix after the semicolon
                if ($entry -match ';(\d)$') {
                    $linkState = [int]$matches[1]
                    switch ($linkState) {
                        0 { $enabledLinks++ }
                        1 { $disabledLinks++ }
                        2 { $enforcedLinks++ }
                    }
                }
            }
        }
    }

    # Test passes if we successfully retrieved GPO link data
    $testResult = $totalLinks -ge 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Links | $totalLinks |`n"
        $result += "| Enabled Links | $enabledLinks |`n"
        $result += "| Disabled Links | $disabledLinks |`n"
        $result += "| Enforced Links | $enforcedLinks |`n"

        if ($totalLinks -gt 0) {
            $disabledPercentage = [Math]::Round(($disabledLinks / $totalLinks) * 100, 2)
            $result += "| Disabled Percentage | $disabledPercentage% |`n"
        }

        $testResultMarkdown = "Active Directory GPO links have been analyzed. $disabledLinks out of $totalLinks links are disabled.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory GPO links. Ensure you have appropriate permissions and the Group Policy Management Console is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
