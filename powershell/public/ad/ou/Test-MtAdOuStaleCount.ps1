function Test-MtAdOuStaleCount {
    <#
    .SYNOPSIS
    Counts the number of Organizational Units that have not been modified since before 2020.

    .DESCRIPTION
    This test identifies OUs that have not been modified since before 2020, which may indicate
    stale or unused organizational units. Stale OUs can accumulate over time and may represent
    outdated organizational structures or abandoned projects. Regular review and cleanup of
    stale OUs helps maintain directory hygiene and reduces confusion.

    .EXAMPLE
    Test-MtAdOuStaleCount

    Returns $true if OU data is accessible, $false otherwise.
    The test result includes the count of stale OUs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdOuStaleCount
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

    # Count total OUs
    $totalCount = ($organizationalUnits | Measure-Object).Count

    # Find stale OUs (not modified since before 2020)
    $cutoffDate = Get-Date -Year 2020 -Month 1 -Day 1
    $staleOUs = $organizationalUnits | Where-Object {
        $modifyTime = if ($_.modifyTimeStamp) { $_.modifyTimeStamp } elseif ($_.whenChanged) { $_.whenChanged } else { $null }
        $createTime = if ($_.createTimeStamp) { $_.createTimeStamp } elseif ($_.whenCreated) { $_.whenCreated } else { $null }

        # Use the most recent of modify or create time
        $lastActivity = if ($modifyTime -and $createTime) {
            if ($modifyTime -gt $createTime) { $modifyTime } else { $createTime }
        } elseif ($modifyTime) { $modifyTime } else { $createTime }

        $lastActivity -and $lastActivity -lt $cutoffDate
    }
    $staleCount = ($staleOUs | Measure-Object).Count

    # Test passes if we successfully retrieved OU data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($staleCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total OUs | $totalCount |`n"
        $result += "| Stale OUs (pre-2020) | $staleCount |`n"
        $result += "| Stale Percentage | $percentage% |`n`n"

        if ($staleCount -gt 0) {
            $result += "**Stale OUs (not modified since before 2020):**`n`n"
            $result += "| OU Name | Last Modified | Distinguished Name |`n"
            $result += "| --- | --- | --- |`n"
            foreach ($ou in ($staleOUs | Sort-Object modifyTimeStamp)) {
                $lastMod = if ($ou.modifyTimeStamp) { $ou.modifyTimeStamp.ToString("yyyy-MM-dd") } else { "Unknown" }
                $result += "| $($ou.Name) | $lastMod | $($ou.DistinguishedName) |`n"
            }
        }

        $testResultMarkdown = "Active Directory Organizational Units have been analyzed. $staleCount OU(s) ($percentage%) have not been modified since before 2020.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory Organizational Units. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


