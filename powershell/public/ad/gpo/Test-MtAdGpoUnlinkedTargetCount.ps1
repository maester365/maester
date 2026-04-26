function Test-MtAdGpoUnlinkedTargetCount {
    <#
    .SYNOPSIS
    Counts AD targets (OUs, domains, sites) that do not have any GPO links.

    .DESCRIPTION
    This test identifies policy deployment gaps by counting Active Directory targets
    (organizational units, the domain root, and site link objects) that have no GPO links.
    
    Targets without GPO links may indicate incomplete security policy coverage and can lead
    to inconsistent enforcement of security baselines.

    .EXAMPLE
    Test-MtAdGpoUnlinkedTargetCount

    Returns $true if no unlinked targets were found, $false if targets without any GPO links exist,
    and $null if AD/GPO data is not accessible.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoUnlinkedTargetCount
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

    function Test-MtGpoLinkPresent {
        param(
            [Parameter(Mandatory = $false)]
            [object]$gPLinkValue
        )

        if ($null -eq $gPLinkValue) {
            return $false
        }

        $text = [string]$gPLinkValue
        if ([string]::IsNullOrWhiteSpace($text)) {
            return $false
        }

        # gPLink contains one or more entries like:
        # LDAP://...CN={GPO-GUID},...;0
        return [regex]::IsMatch($text, '\{[0-9a-fA-F-]{36}\}')
    }

    # Collect targets without any GPO links
    $unlinkedOus = @()
    $unlinkedDomains = @()
    $unlinkedSites = @()

    # OUs
    try {
        $ous = Get-ADOrganizationalUnit -Filter * -Properties DistinguishedName, gPLink
        if ($null -ne $ous) {
            foreach ($ou in @($ous)) {
                $ouLink = $null
                if ($ou.PSObject.Properties.Match('gPLink')) {
                    $ouLink = $ou.gPLink
                }

                if (-not (Test-MtGpoLinkPresent -gPLinkValue $ouLink)) {
                    $unlinkedOus += $ou
                }
            }
        }
    }
    catch {
        Add-MtTestResultDetail -Result 'Unable to retrieve Active Directory organizational units (OUs). Ensure you have the Active Directory module installed and sufficient permissions.'
        return $false
    }

    # Domain root
    try {
        $domain = Get-ADDomain
        $domainObj = Get-ADObject -Identity $domain.DistinguishedName -Properties DistinguishedName, gPLink
        $domainLink = $null
        if ($domainObj -and $domainObj.PSObject.Properties.Match('gPLink')) {
            $domainLink = $domainObj.gPLink
        }

        if (-not (Test-MtGpoLinkPresent -gPLinkValue $domainLink)) {
            $unlinkedDomains = @($domainObj)
        }
    }
    catch {
        Add-MtTestResultDetail -Result 'Unable to retrieve the Active Directory domain root configuration. Ensure you have the Active Directory module installed and sufficient permissions.'
        return $false
    }

    # Sites (siteLink objects)
    $siteContainers = $gpoState.SiteContainers
    $siteLinks = @()
    if ($null -ne $siteContainers) {
        foreach ($obj in @($siteContainers)) {
            $objectClass = $obj.ObjectClass

            if ($null -eq $objectClass) {
                continue
            }

            if ($objectClass -is [System.Array]) {
                if ($objectClass -contains 'siteLink') {
                    $siteLinks += $obj
                }
            }
            else {
                if ([string]$objectClass -eq 'siteLink') {
                    $siteLinks += $obj
                }
            }
        }
    }

    foreach ($siteLink in @($siteLinks)) {
        $siteLinkValue = $null
        if ($siteLink.PSObject.Properties.Match('gPLink')) {
            $siteLinkValue = $siteLink.gPLink
        }

        if (-not (Test-MtGpoLinkPresent -gPLinkValue $siteLinkValue)) {
            $unlinkedSites += $siteLink
        }
    }

    $totalOus = if ($null -ne $ous) { ($ous | Measure-Object).Count } else { 0 }
    $totalDomains = if ($null -ne $domainObj) { 1 } else { 0 }
    $totalSites = @($siteLinks).Count

    $unlinkedCountOus = @($unlinkedOus).Count
    $unlinkedCountDomains = @($unlinkedDomains).Count
    $unlinkedCountSites = @($unlinkedSites).Count

    $totalUnlinkedTargets = $unlinkedCountOus + $unlinkedCountDomains + $unlinkedCountSites
    $testResult = $totalUnlinkedTargets -eq 0

    # Sample unlinked targets
    $sampleLimit = 5
    $sample = @()
    $sample += @($unlinkedOus | Sort-Object DistinguishedName | Select-Object -First $sampleLimit | ForEach-Object {
        'OU: ' + [string]$_.DistinguishedName
    })

    if ($sample.Count -lt $sampleLimit -and $unlinkedDomains.Count -gt 0) {
        $sample += @('Domain: ' + [string]$unlinkedDomains[0].DistinguishedName)
    }

    if ($sample.Count -lt $sampleLimit -and $unlinkedSites.Count -gt 0) {
        $remaining = $sampleLimit - $sample.Count
        $sample += @($unlinkedSites | Sort-Object DistinguishedName | Select-Object -First $remaining | ForEach-Object {
            'SiteLink: ' + [string]$_.DistinguishedName
        })
    }

    $sampleText = ($sample | Where-Object { $_ }) -join ', '
    if ($totalUnlinkedTargets -gt $sampleLimit -and $sampleText) {
        $sampleText += " (showing first $sampleLimit)"
    }

    $result = "| Metric | Value |`n"
    $result += "| --- | --- |`n"
    $result += "| Total OUs | $totalOus |`n"
    $result += "| Unlinked OUs | $unlinkedCountOus |`n"
    $result += "| Total Domains | $totalDomains |`n"
    $result += "| Unlinked Domains | $unlinkedCountDomains |`n"
    $result += "| Total Sites (siteLink) | $totalSites |`n"
    $result += "| Unlinked Sites (siteLink) | $unlinkedCountSites |`n"
    $result += "| Total Unlinked Targets | $totalUnlinkedTargets |`n"
    if ($sampleText) {
        # Avoid breaking markdown tables when DNs contain pipes
        # Use [regex]::Escape to properly escape the pipe character for regex replacement
        $safeSampleText = $sampleText -replace '\|', '&#124;'
        $result += "| Sample Unlinked Targets | $safeSampleText |`n"
    }

    if ($testResult) {
        $testResultMarkdown = "✅ All analyzed targets (OUs, domain root, and sites) have at least one GPO link. This indicates consistent GPO-based security policy coverage.`n`n%TestResult%"
    }
    else {
        $testResultMarkdown = "⚠️ One or more Active Directory targets do not have any GPO links ($totalUnlinkedTargets). Unlinked targets can indicate incomplete policy coverage, leading to inconsistent security enforcement across the environment.`n`n%TestResult%"
    }

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown
    return $testResult
}
