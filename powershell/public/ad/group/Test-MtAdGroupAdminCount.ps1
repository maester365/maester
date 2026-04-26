function Test-MtAdGroupAdminCount {
    <#
    .SYNOPSIS
    Counts groups with AdminCount set in Active Directory.

    .DESCRIPTION
    This test identifies groups that have the AdminCount attribute set to a non-null or non-zero value.
    The AdminCount attribute is automatically set by Active Directory on privileged accounts and groups
    that are members of protected groups (like Domain Admins, Enterprise Admins, etc.). Groups with
    AdminCount set receive special security protections to prevent delegation of administrative privileges.

    .EXAMPLE
    Test-MtAdGroupAdminCount

    Returns $true if group data is accessible, $false otherwise.
    The test result includes the count of groups with AdminCount set.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupAdminCount
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

    # Count groups with AdminCount set
    $groupsWithAdminCount = $groups | Where-Object {
        $null -ne $_.adminCount -and $_.adminCount -gt 0
    }

    $adminCountGroups = ($groupsWithAdminCount | Measure-Object).Count
    $totalCount = ($groups | Measure-Object).Count

    # Test passes if we successfully retrieved group data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($adminCountGroups / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalCount |`n"
        $result += "| Groups with AdminCount | $adminCountGroups |`n"
        $result += "| AdminCount Percentage | $percentage% |`n`n"

        $testResultMarkdown = "Active Directory groups have been analyzed. $adminCountGroups out of $totalCount groups ($percentage%) have AdminCount set.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory groups. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


