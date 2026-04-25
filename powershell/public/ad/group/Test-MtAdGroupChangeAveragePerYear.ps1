function Test-MtAdGroupChangeAveragePerYear {
    <#
    .SYNOPSIS
    Calculates the average group membership changes per year in Active Directory.

    .DESCRIPTION
    This test analyzes the modification dates of groups and their memberships
    to calculate the average number of membership changes per year across all groups.
    This helps identify the rate of change in group membership and can highlight
    periods of high activity or potential security concerns.

    The calculation includes:
    - Group creation dates
    - Group modification dates
    - Analysis of when membership changes likely occurred

    .EXAMPLE
    Test-MtAdGroupChangeAveragePerYear

    Returns $true if data is retrievable.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupChangeAveragePerYear
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $adState = Get-MtADDomainState
    if ($null -eq $adState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $groups = $adState.Groups

    # Calculate date range
    $now = Get-Date
    $oldestGroup = $groups | Where-Object { $_.createTimeStamp } | Sort-Object createTimeStamp | Select-Object -First 1
    $newestGroup = $groups | Where-Object { $_.createTimeStamp } | Sort-Object createTimeStamp -Descending | Select-Object -First 1

    if ($oldestGroup -and $newestGroup) {
        $oldestDate = $oldestGroup.createTimeStamp
        $newestDate = $newestGroup.createTimeStamp
        $timespan = $newestDate - $oldestDate
        $yearsActive = [Math]::Max(1, [Math]::Round($timespan.TotalDays / 365, 1))
    } else {
        $yearsActive = 1
        $oldestDate = $now.AddYears(-1)
    }

    # Analyze group modifications
    $recentlyModified = @()
    $thisYear = $now.Year
    $lastYear = $thisYear - 1

    $modificationsByYear = @{}
    $creationsByYear = @{}

    for ($year = $oldestDate.Year; $year -le $thisYear; $year++) {
        $modificationsByYear[$year] = 0
        $creationsByYear[$year] = 0
    }

    foreach ($group in $groups) {
        # Track creations by year
        if ($group.createTimeStamp) {
            $creationYear = $group.createTimeStamp.Year
            if ($creationsByYear.ContainsKey($creationYear)) {
                $creationsByYear[$creationYear]++
            }
        }

        # Track modifications by year
        if ($group.modifyTimeStamp) {
            $modificationYear = $group.modifyTimeStamp.Year
            if ($modificationsByYear.ContainsKey($modificationYear)) {
                $modificationsByYear[$modificationYear]++
            }

            # Track recently modified groups (within last 90 days)
            $daysSinceModified = ($now - $group.modifyTimeStamp).Days
            if ($daysSinceModified -le 90) {
                $recentlyModified += [PSCustomObject]@{
                    Name = $group.Name
                    LastModified = $group.modifyTimeStamp
                    DaysAgo = $daysSinceModified
                }
            }
        }
    }

    # Calculate averages
    $totalGroups = ($groups | Measure-Object).Count
    $totalCreations = ($creationsByYear.Values | Measure-Object -Sum).Sum
    $totalModifications = ($modificationsByYear.Values | Measure-Object -Sum).Sum
    $averageChangesPerYear = [Math]::Round($totalModifications / $yearsActive, 1)

    $testResult = $true

    if ($testResult) {
        $result = "### Group Membership Change Analysis`n`n"

        $result += "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalGroups |`n"
        $result += "| Years Active | $yearsActive |`n"
        $result += "| Oldest Group Created | $($oldestDate.ToString('yyyy-MM-dd')) |`n"
        $result += "| Total Modifications | $totalModifications |`n"
        $result += "| Average Changes Per Year | $averageChangesPerYear |`n"
        $result += "| Recently Modified (90 days) | $($recentlyModified.Count) |`n"

        $result += "`n### Changes by Year`n`n"
        $result += "| Year | Groups Created | Groups Modified |`n"
        $result += "| --- | --- | --- |`n"

        $sortedYears = $modificationsByYear.Keys | Sort-Object
        foreach ($year in $sortedYears) {
            $created = $creationsByYear[$year]
            $modified = $modificationsByYear[$year]
            $result += "| $year | $created | $modified |`n"
        }

        if ($recentlyModified.Count -gt 0) {
            $result += "`n### Recently Modified Groups (Last 90 Days)`n`n"
            $result += "| Group Name | Last Modified | Days Ago |`n"
            $result += "| --- | --- | --- |`n"

            $sortedRecent = $recentlyModified | Sort-Object DaysAgo
            foreach ($group in ($sortedRecent | Select-Object -First 20)) {
                $result += "| $($group.Name) | $($group.LastModified.ToString('yyyy-MM-dd')) | $($group.DaysAgo) |`n"
            }

            if ($recentlyModified.Count -gt 20) {
                $result += "`n> *... and $($recentlyModified.Count - 20) more groups*`n"
            }
        }

        $testResultMarkdown = $result
    } else {
        $testResultMarkdown = "Unable to retrieve group change data."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
