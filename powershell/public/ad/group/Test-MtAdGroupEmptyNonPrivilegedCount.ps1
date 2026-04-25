function Test-MtAdGroupEmptyNonPrivilegedCount {
    <#
    .SYNOPSIS
    Counts empty non-privileged groups in Active Directory.

    .DESCRIPTION
    This test counts groups that have no members and are not privileged
    (do not have adminCount = 1). Empty groups that are not privileged
    may be candidates for cleanup as they serve no purpose in access control.

    .EXAMPLE
    Test-MtAdGroupEmptyNonPrivilegedCount

    Returns $true if data is retrievable.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGroupEmptyNonPrivilegedCount
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
    $totalGroups = ($groups | Measure-Object).Count

    # Count empty non-privileged groups
    $emptyNonPrivilegedGroups = 0
    $emptyPrivilegedGroups = 0
    $nonEmptyGroups = 0

    foreach ($group in $groups) {
        try {
            $members = Get-ADGroupMember -Identity $group.DistinguishedName -ErrorAction SilentlyContinue
            $memberCount = ($members | Measure-Object).Count

            if ($memberCount -eq 0) {
                # Check if group is privileged (adminCount = 1)
                if ($group.adminCount -eq 1) {
                    $emptyPrivilegedGroups++
                } else {
                    $emptyNonPrivilegedGroups++
                }
            } else {
                $nonEmptyGroups++
            }
        }
        catch {
            Write-Verbose "Could not check members for group $($group.Name): $($_.Exception.Message)"
        }
    }

    $testResult = $true

    if ($testResult) {
        $result = "| Category | Count |`n"
        $result += "| --- | --- |`n"
        $result += "| Total Groups | $totalGroups |`n"
        $result += "| Empty Non-Privileged Groups | $emptyNonPrivilegedGroups |`n"
        $result += "| Empty Privileged Groups | $emptyPrivilegedGroups |`n"
        $result += "| Groups with Members | $nonEmptyGroups |`n"

        if ($totalGroups -gt 0) {
            $emptyPercentage = [Math]::Round(($emptyNonPrivilegedGroups / $totalGroups) * 100, 2)
            $result += "| Empty Non-Privileged Percentage | $emptyPercentage% |`n"
        }

        $testResultMarkdown = "Active Directory group analysis found **$emptyNonPrivilegedGroups** empty non-privileged groups out of **$totalGroups** total groups.`n`n"
        $testResultMarkdown += "Empty non-privileged groups may be candidates for cleanup.`n`n%TestResult%"
        $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result
    } else {
        $testResultMarkdown = "Unable to retrieve group data."
    }

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
