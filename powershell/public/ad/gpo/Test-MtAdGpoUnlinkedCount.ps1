function Test-MtAdGpoUnlinkedCount {
    <#
    .SYNOPSIS
    Counts Active Directory GPOs that are not linked to any OU, domain, or site.

    .DESCRIPTION
    This test identifies "orphaned" (unlinked) Group Policy Objects (GPOs) that exist in Active Directory
    but are not linked to any OU, domain, or site. Unlinked GPOs can consume administrative and processing
    resources while providing no effective policy.

    .EXAMPLE
    Test-MtAdGpoUnlinkedCount

    Returns $true if unlinked GPOs were not found, $false if orphaned/unlinked GPOs exist.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoUnlinkedCount
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

    $gpos = $gpoState.GPOs
    $totalCount = ($gpos | Measure-Object).Count

    # Collect GPO IDs that appear in GPOLinks (gPLink) across the collected AD containers.
    # Get-MtADGpoState currently retrieves GPOLinks from Configuration naming context (sites-related searchbase).
    $linkedGpoIds = [System.Collections.Generic.HashSet[string]]::new([StringComparer]::OrdinalIgnoreCase)
    $gpLinks = $gpoState.GPOLinks
    if ($gpLinks) {
        foreach ($linkObject in $gpLinks) {
            $gPLinkValue = $linkObject.gPLink
            if ([string]::IsNullOrWhiteSpace($gPLinkValue)) {
                continue
            }

            # gPLink contains one or more entries like:
            # LDAP://CN=...,CN=Policies,CN=System,DC=example,DC=com;{GPO-GUID};0
            foreach ($match in ([regex]::Matches($gPLinkValue, '\{([0-9a-fA-F-]{36})\}'))) {
                $guid = $match.Groups[1].Value
                if (-not [string]::IsNullOrWhiteSpace($guid)) {
                    $linkedGpoIds.Add($guid) | Out-Null
                }
            }
        }
    }

    # Identify unlinked/orphaned GPOs by comparing the GPO IDs against collected link targets.
    $unlinkedGpos = @()
    foreach ($gpo in $gpos) {
        $gpoId = if ($null -ne $gpo.Id) { [string]$gpo.Id } else { $null }

        # Optional fallback: some environments may surface unlinked wording in GpoStatus.
        $statusText = if ($null -ne $gpo.GpoStatus) { [string]$gpo.GpoStatus } else { $null }
        $looksUnlinked = $false
        if ($statusText -and ($statusText -match 'Unlinked|No links|Not linked')) {
            $looksUnlinked = $true
        }

        $isLinked = $false
        if ($gpoId) {
            $isLinked = $linkedGpoIds.Contains($gpoId)
        }

        if (-not $isLinked -or $looksUnlinked) {
            $unlinkedGpos += $gpo
        }
    }

    $unlinkedCount = ($unlinkedGpos | Measure-Object).Count
    $linkedCount = $totalCount - $unlinkedCount

    # Sample names for operator visibility
    $sampleLimit = 5
    $sampleUnlinked = $unlinkedGpos | Select-Object -First $sampleLimit
    $sampleNames = @($sampleUnlinked | ForEach-Object {
        if ($_.DisplayName) { $_.DisplayName } else { $_.Id }
    })
    $sampleNamesText = ($sampleNames | Where-Object { $_ }) -join ', '
    if ($unlinkedCount -gt $sampleLimit -and $sampleNamesText) {
        $sampleNamesText += " (showing first $sampleLimit)"
    }

    # Security intent: pass only when no unlinked/orphaned GPOs exist.
    $testResult = $unlinkedCount -eq 0

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total GPOs | $totalCount |`n"
    $result += "| Linked GPOs | $linkedCount |`n"
    $result += "| Unlinked GPOs | $unlinkedCount |`n"
    if ($unlinkedCount -gt 0 -and $sampleNamesText) {
        $result += "| Sample Unlinked GPOs | $sampleNamesText |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "✅ Unlinked/orphaned GPOs have not been found. Active Directory Group Policy Objects have been analyzed successfully.`n`n%TestResult%"
    } else {
        $testResultMarkdown = "⚠️ Unlinked/orphaned GPOs were found. These GPOs consume resources while providing no effective policy, and they can be accidentally linked later, applying unknown settings. After verification, remove or remediate unlinked GPOs.`n`n%TestResult%"
    }
    $testResultMarkdown = $testResultMarkdown -replace "%TestResult%", $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}



