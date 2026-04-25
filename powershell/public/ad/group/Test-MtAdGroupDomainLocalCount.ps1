function Test-MtAdGroupDomainLocalCount {
    <#
    .SYNOPSIS
    Counts the number of domain local groups in Active Directory.

    .DESCRIPTION
    This test counts domain local groups in Active Directory. Domain local groups can only
    be used to assign permissions to resources within the same domain where the group exists.
    They can contain users and global groups from any domain, but can only be assigned
    permissions to resources in their own domain. These groups are typically used for
    resource access control within a single domain.

    .EXAMPLE
    Test-MtAdGroupDomainLocalCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes counts of domain local groups.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupDomainLocalCount
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

    $groups = $adState.Groups

    # Count domain local groups (GroupScope = "DomainLocal")
    $domainLocalGroups = $groups | Where-Object { $_.GroupScope -eq "DomainLocal" }
    $domainLocalCount = ($domainLocalGroups | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($domainLocalCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Domain Local Groups | $domainLocalCount |`n"
        $result += "| Domain Local Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory group objects have been analyzed. $domainLocalCount out of $totalCount groups ($percentage%) are domain local groups (resources in local domain only).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory group objects. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}
