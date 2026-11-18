function Test-MtAdGpoEnforcedCount {
    <#
    .SYNOPSIS
    Inventories enforced GPO links, which override blocked inheritance.

    .DESCRIPTION
    This test retrieves Active Directory GPO link state information using Get-MtADGpoState and then counts
    how many GPO link entries are marked as **Enforced**.

    Enforced GPO links cannot be blocked by child OUs, which means security-related policies can apply
    everywhere even when lower-level inheritance would normally disable them.

    .EXAMPLE
    Test-MtAdGpoEnforcedCount

    Reports Investigate when enforced-link inventory is available, regardless of count.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoEnforcedCount
    #>
    [MaesterTest(
        Id = 'AD-GPOL-04',
        Title = 'Enforced GPO link count should be retrievable',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'infrastructure',
        ResourceType = 'GroupPolicy',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoEnforcedCount"

    $gpoState = Get-MtADGpoState

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'GPO state is unavailable; enforced-link counts cannot be determined.'
        return $null
    }

    $gpoLinks = $gpoState.GPOLinks
    if ($null -eq $gpoLinks) {
        Add-MtTestResultDetail -SkippedBecause Error -Result 'GPO link inventory is unavailable; enforced-link counts cannot be determined.'
        return
    }

    $totalLinks = if ($null -ne $gpoLinks) { ($gpoLinks | Measure-Object).Count } else { 0 }

    $enforcedCount = 0
    if ($null -ne $gpoLinks) {
        foreach ($linkObj in $gpoLinks) {
            if ($null -eq $linkObj) {
                continue
            }

            # Get-MtADGpoState surfaces an Enforced property on link objects.
            if ($null -ne $linkObj.Enforced -and [bool]$linkObj.Enforced) {
                $enforcedCount++
            }
        }
    }

    $enforcedPercentage = if ($totalLinks -gt 0) { [math]::Round(($enforcedCount / $totalLinks) * 100, 2) } else { 0 }

    # Enforcement can be intentional; this inventory requires review, not a failure.
    $testResult = $null -ne $gpoState.GPOLinks

    $resultTable = "| Metric | Value |" + "`n"
    $resultTable += "| --- | --- |" + "`n"
    $resultTable += "| Total GPO link entries | $totalLinks |" + "`n"
    $resultTable += "| Enforced GPO link entries | $enforcedCount |" + "`n"
    $resultTable += "| Enforced link ratio | $enforcedPercentage% |" + "`n"

    if ($enforcedCount -eq 0) {
        $recommendation = 'No enforced GPO links were detected in the visible inventory. Review link and inheritance design against the intended policy scope.'
    }
    else {
        $recommendation = "⚠️ Enforced GPO links were detected ($enforcedCount). Enforced links override inheritance blocking at child OUs, so they can significantly impact security posture. Review and use enforced links sparingly for critical policies that must apply everywhere."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    return $testResult
}
