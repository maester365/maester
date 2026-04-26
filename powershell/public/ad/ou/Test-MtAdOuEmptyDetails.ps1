function Test-MtAdOuEmptyDetails {
    <#
    .SYNOPSIS
    Provides detailed information about empty Organizational Units in Active Directory.

    .DESCRIPTION
    This test lists all OUs that do not contain any user, group, or computer objects, along with
    their creation date and distinguished name. This detailed view helps administrators identify
    and evaluate empty OUs for potential deletion or repurposing. The information assists in
    directory cleanup efforts and organizational planning.

    .EXAMPLE
    Test-MtAdOuEmptyDetails

    Returns $true if OU data is accessible, $false otherwise.
    The test result includes a detailed list of all empty OUs.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdOuEmptyDetails
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
    $users = $adState.Users
    $groups = $adState.Groups
    $computers = $adState.Computers

    # Count total OUs
    $totalCount = ($organizationalUnits | Measure-Object).Count

    # Find empty OUs (no direct children that are users, groups, or computers)
    $emptyOUs = @()
    foreach ($ou in $organizationalUnits) {
        $ouDn = $ou.DistinguishedName

        # Check if any users are directly in this OU
        $hasUsers = $users | Where-Object { $_.DistinguishedName -match "^[^,]+,$ouDn$" }

        # Check if any groups are directly in this OU
        $hasGroups = $groups | Where-Object { $_.DistinguishedName -match "^[^,]+,$ouDn$" }

        # Check if any computers are directly in this OU
        $hasComputers = $computers | Where-Object { $_.DistinguishedName -match "^[^,]+,$ouDn$" }

        # If no users, groups, or computers, it's empty
        if (-not $hasUsers -and -not $hasGroups -and -not $hasComputers) {
            $emptyOUs += $ou
        }
    }
    $emptyCount = ($emptyOUs | Measure-Object).Count

    # Test passes if we successfully retrieved OU data
    $testResult = $totalCount -gt 0

    # Generate markdown results
    if ($testResult) {
        $percentage = if ($totalCount -gt 0) {
            [Math]::Round(($emptyCount / $totalCount) * 100, 2)
        } else {
            0
        }

        $result = "| Metric | Value |`n"
        $result += "| --- | --- |`n"
        $result += "| Total OUs | $totalCount |`n"
        $result += "| Empty OUs | $emptyCount |`n"
        $result += "| Empty Percentage | $percentage% |`n`n"

        if ($emptyCount -gt 0) {
            $result += "**Empty Organizational Units:**`n`n"
            $result += "| OU Name | Created | Distinguished Name |`n"
            $result += "| --- | --- | --- |`n"
            foreach ($ou in ($emptyOUs | Sort-Object Name)) {
                $created = if ($ou.createTimeStamp) { $ou.createTimeStamp.ToString("yyyy-MM-dd") } elseif ($ou.whenCreated) { $ou.whenCreated.ToString("yyyy-MM-dd") } else { "Unknown" }
                $result += "| $($ou.Name) | $created | $($ou.DistinguishedName) |`n"
            }
        } else {
            $result += "**No empty OUs found.** All OUs contain at least one user, group, or computer object.`n"
        }

        $testResultMarkdown = "Active Directory Organizational Units have been analyzed. $emptyCount OU(s) ($percentage%) are empty (contain no users, groups, or computers).`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve Active Directory Organizational Units. Ensure you have appropriate permissions and the Active Directory module is installed."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown

    return $testResult
}


