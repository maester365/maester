function Test-MtAdOuAtDomainRootCount {
    <#
    .SYNOPSIS
    Counts the number of Organizational Units at the domain root level in Active Directory.

    .DESCRIPTION
    This test counts OUs that are direct children of the domain root (e.g., DC=maester,DC=test).
    Understanding the OU structure at the root level helps assess the organization and hierarchy
    of the directory. A flat structure with many root-level OUs may indicate a need for better
    organizational hierarchy.

    .EXAMPLE
    Test-MtAdOuAtDomainRootCount

    Returns $true if OU data is accessible, $false otherwise.
    The test result includes the count of root-level OUs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdOuAtDomainRootCount
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

    $organizationalUnits = $adState.OrganizationalUnits
    $domain = $adState.Domain

    # Count total OUs
    $totalCount = ($organizationalUnits | Measure-Object).Count

    # Find OUs at domain root level (direct children of domain root)
    $domainDn = $domain.DistinguishedName
    $rootLevelOUs = $organizationalUnits | Where-Object {
        $_.DistinguishedName -match "^OU=[^,]+,$domainDn$"
    }
    $rootLevelCount = ($rootLevelOUs | Measure-Object).Count

    # Calculate nested OUs
    $nestedCount = $totalCount - $rootLevelCount

    # Test passes if we successfully retrieved OU data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total OUs | $totalCount |`n"
        $result += "| Root-Level OUs | $rootLevelCount |`n"
        $result += "| Nested OUs | $nestedCount |`n`n"

        if ($rootLevelCount -gt 0) {
            $result += "**Root-Level OUs:**`n`n"
            $result += "| OU Name | Distinguished Name |`n"
            $result += "| --- | --- |`n"
            foreach ($ou in ($rootLevelOUs | Sort-Object Name)) {
                $result += "| $($ou.Name) | $($ou.DistinguishedName) |`n"
            }
        }

        $testResultMarkdown = "Active Directory Organizational Unit structure has been analyzed. $rootLevelCount OU(s) exist at the domain root level out of $totalCount total OU(s).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory Organizational Units. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


