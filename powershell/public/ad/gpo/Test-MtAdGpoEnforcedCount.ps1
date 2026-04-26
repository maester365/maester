function Test-MtAdGpoEnforcedCount {
    <#
    .SYNOPSIS
    Counts enforced GPO links (links that block inheritance).

    .DESCRIPTION
    This test retrieves Active Directory GPO link state information using Get-MtADGpoState and then counts
    how many GPO link entries are marked as **Enforced**.

    Enforced GPO links cannot be blocked by child OUs, which means security-related policies can apply
    everywhere even when lower-level inheritance would normally disable them.

    .EXAMPLE
    Test-MtAdGpoEnforcedCount

    Returns $true when no enforced GPO links are detected, $false when enforced GPO links exist.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoEnforcedCount
    #>
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    $gpoState = Get-MtADGpoState

    if ($null -eq $gpoState) {
        Add-MtTestResultDetail -SkippedBecause NotConnectedActiveDirectory
        return $null
    }

    $gpoLinks = $gpoState.GPOLinks

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

    # Security intent: flag environments that use enforced links (they override inheritance blocking).
    $testResult = $enforcedCount -eq 0

    $resultTable = "| Metric | Value |`n"
    $resultTable += "| --- | --- |`n"
    $resultTable += "| Total GPO link entries | $totalLinks |`n"
    $resultTable += "| Enforced GPO link entries | $enforcedCount |`n"
    $resultTable += "| Enforced link ratio | $enforcedPercentage% |`n"

    if ($testResult) {
        $recommendation = "✅ No enforced GPO links (inheritance-blocking links) were detected. Active Directory Group Policy Objects have been analyzed successfully."
    }
    else {
        $recommendation = "⚠️ Enforced GPO links were detected ($enforcedCount). Enforced links override inheritance blocking at child OUs, so they can significantly impact security posture. Review and use enforced links sparingly for critical policies that must apply everywhere."
    }

    $testResultMarkdown = "$recommendation`n`n%TestResult%"
    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $resultTable

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



