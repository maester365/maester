function Test-MtAdGpoLinkedOUCount {
    <#
    .SYNOPSIS
    Counts the number of Organizational Units with GPO links in Active Directory.

    .DESCRIPTION
    This test retrieves the count of OUs that have one or more GPOs linked to them.
    Understanding GPO distribution across OUs helps assess policy coverage and
    identify potential gaps in security policy application.

    .EXAMPLE
    Test-MtAdGpoLinkedOUCount

    Returns $true if GPO link data is accessible, $false otherwise.
    The test result includes counts of OUs with and without GPO links.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoLinkedOUCount
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

    # Get all OUs in the domain
    try {
        $allOUs = Get-ADOrganizationalUnit -Filter * -Properties gPLink
        $totalOUs = ($allOUs | Measure-Object).Count

        # Count OUs with GPO links (gPLink is not null or empty)
        $linkedOUs = $allOUs | Where-Object { $_.gPLink -and $_.gPLink -ne '' }
        $linkedOUCount = ($linkedOUs | Measure-Object).Count
        $unlinkedOUCount = $totalOUs - $linkedOUCount

        # Test passes if we successfully retrieved data
        $testResult = $totalOUs -ge 0

        # Generate markdown results
        if ($testResult) {
            $result = "| Metric | Value |`n"
            $result += "| --- | --- |`n"
            $result += "| Total OUs | $totalOUs |`n"
            $result += "| OUs with GPO Links | $linkedOUCount |`n"
            $result += "| OUs without GPO Links | $unlinkedOUCount |`n"

            if ($totalOUs -gt 0) {
                $linkedPercentage = [Math]::Round(($linkedOUCount / $totalOUs) * 100, 2)
                $result += "| Linked OU Percentage | $linkedPercentage% |`n"
            }

            $testResultMarkdown = "Active Directory Organizational Units have been analyzed. $linkedOUCount out of $totalOUs OUs have GPO links.`n`n%TestResult%"
            $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
        } else {
            $testResultMarkdown = "Unable to retrieve Active Directory OU data. Ensure you have appropriate permissions."
        }
    }
    catch {
        Write-Verbose "Error retrieving OU data: $($_.Exception.Message)"
        $testResult = $false
        $testResultMarkdown = "Error retrieving OU data: $($_.Exception.Message)"
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}




