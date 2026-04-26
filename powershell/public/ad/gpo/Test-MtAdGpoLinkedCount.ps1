function Test-MtAdGpoLinkedCount {
    <#
    .SYNOPSIS
    Counts distinct GPOs that have at least one enabled link (active GPOs).

    .DESCRIPTION
    This test retrieves Active Directory GPO state information using Get-MtADGpoState, then counts distinct
    Group Policy Objects (GPOs) that have at least one enabled link.

    Understanding the scope of actively linked (and therefore applying) policies is important for security
    assessments. Comparing total GPOs vs linked GPOs helps identify the ratio of active vs unused policies.

    .EXAMPLE
    Test-MtAdGpoLinkedCount

    Returns $true if GPO data is accessible, $false otherwise.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoLinkedCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpos = $gpoState.GPOs
    $totalCount = if ($null -ne $gpos) { ($gpos | Measure-Object).Count } else { 0 }

    # gPLink syntax includes entries like:
    # [LDAP://...CN={GPO-GUID},...;0]  -> enabled
    # [LDAP://...CN={GPO-GUID},...;1]  -> disabled
    # [LDAP://...CN={GPO-GUID},...;2]  -> enforced
    $linkedGuidSet = [System.Collections.Generic.HashSet[string]]::new()

    $gpoLinks = $gpoState.GPOLinks
    if ($null -ne $gpoLinks) {
        foreach ($linkObj in $gpoLinks) {
            $gPLinkValue = $linkObj.gPLink
            if ([string]::IsNullOrEmpty($gPLinkValue)) {
                continue
            }

            $pattern = '\[\s*LDAP://[^\]]*?\{(?<guid>[0-9a-fA-F-]{36})\}[^\]]*?;\s*(?<status>\d)\s*\]'
            $regexMatches = [regex]::Matches([string]$gPLinkValue, $pattern)

            foreach ($match in $regexMatches) {
                $guid = $match.Groups['guid'].Value
                $status = [int]$match.Groups['status'].Value

                # 0 = enabled, 2 = enforced. Count both as active links.
                if ($status -in 0, 2) {
                    [void]$linkedGuidSet.Add($guid)
                }
            }
        }
    }

    $linkedCount = $linkedGuidSet.Count
    $linkedPercentage = if ($totalCount -gt 0) { [math]::Round(($linkedCount / $totalCount) * 100, 2) } else { 0 }

    $testResult = $true

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPOs | $totalCount |`n"
    $resultTable += "| Linked GPOs (Active) | $linkedCount |`n"
    $resultTable += "| Linked Ratio | $linkedPercentage% |`n"

    $testResultMarkdown = "Active Directory Group Policy Objects have been analyzed. The domain contains $totalCount GPO(s); $linkedCount GPO(s) are linked and active across at least one scope (domain, OU, or site).`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



