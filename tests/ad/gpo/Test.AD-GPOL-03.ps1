function Test-MtAdGpoUnlinkedTargetCount {
    <#
    .SYNOPSIS
    Reports direct GPO links on OUs, domain roots and sites for investigation.

    .DESCRIPTION
    Counts linked and unlinked OUs and lists targets with no direct GPO links.
    A target can inherit policy from its parent, so absence of a direct link is not
    proof of a policy gap. This inventory requires manual review of effective policy.

    .EXAMPLE
    Test-MtAdGpoUnlinkedTargetCount

    Reports Investigate when target collection succeeds.

    .LINK
    https://maester.dev/docs/commands/Test-MtAdGpoUnlinkedTargetCount
    #>
    [MaesterTest(
        Id = 'AD-GPOL-03',
        Title = 'Direct GPO link coverage should be investigated',
        Product = 'ad',
        Feature = 'group-policy',
        Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit',
        Severity = 'Info',
        Mitre = 'None',
        Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()

    Write-Verbose "Starting Test-MtAdGpoUnlinkedTargetCount"

    # Get AD GPO state data (uses cached data if available)
    $gpoState = Get-MtADGpoState

    # If unable to retrieve GPO data, skip the test
    if ($null -eq $gpoState -or $null -eq $gpoState.LinkContainers -or $null -eq $gpoState.SiteContainers) {
        throw 'Domain, OU or site GPO link containers were not retrieved.'
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
    $ous = @($gpoState.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'organizationalUnit' })
    foreach ($ou in $ous) {
        if (-not (Test-MtGpoLinkPresent -gPLinkValue $ou.GpLink)) {
            $unlinkedOus += $ou
        }
    }

    # Domain root
    $domainObj = $gpoState.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'domainDNS' } | Select-Object -First 1
    if ($null -ne $domainObj -and -not (Test-MtGpoLinkPresent -gPLinkValue $domainObj.GpLink)) {
        $unlinkedDomains = @($domainObj)
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

            if (@($objectClass) -contains 'site') {
                $siteLinks += $obj
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
    $testResult = $true

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

    $result = "| Metric | Value |" + "`n"
    $result += "| --- | --- |" + "`n"
    $result += "| Total OUs | $totalOus |" + "`n"
    $result += "| Unlinked OUs | $unlinkedCountOus |" + "`n"
    $result += "| Total Domains | $totalDomains |" + "`n"
    $result += "| Unlinked Domains | $unlinkedCountDomains |" + "`n"
    $result += "| OUs with direct links | $($totalOus - $unlinkedCountOus) |" + "`n"
    $result += "| Total Sites | $totalSites |" + "`n"
    $result += "| Sites without direct links | $unlinkedCountSites |" + "`n"
    $result += "| Total Unlinked Targets | $totalUnlinkedTargets |" + "`n"
    if ($sampleText) {
        # Avoid breaking markdown tables when DNs contain pipes
        # Use [regex]::Escape to properly escape the pipe character for regex replacement
        $safeSampleText = $sampleText -replace '\|', '&#124;'
        $result += "| Sample Unlinked Targets | $safeSampleText |" + "`n"
    }

    $result += "`n| Target without direct links | Distinguished name |`n| --- | --- |`n"
    foreach ($target in @($unlinkedOus) + @($unlinkedDomains) + @($unlinkedSites)) {
        $dn = ([string]$target.DistinguishedName).Replace('|', '&#124;') -replace '[\r\n]+', ' '
        $type = @($target.ObjectClass)[-1]
        $result += "| $type | $dn |`n"
    }
    $testResultMarkdown = "Investigate direct GPO links and inherited policy. $totalUnlinkedTargets target(s) have no direct links; this does not establish whether security policy is effective.`n`n%TestResult%"

    $testResultMarkdown = $testResultMarkdown -replace '%TestResult%', $result

    Add-MtTestResultDetail -Result $testResultMarkdown -Investigate
    return $testResult
}
