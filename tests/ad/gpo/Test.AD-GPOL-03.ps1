function Test-MtAdGpoUnlinkedTargetCount {
    <#
    .SYNOPSIS
    Inventories direct GPO link coverage for investigation.

    .DESCRIPTION
    Counts linked and unlinked OUs and lists OUs, the domain root and sites without
    direct GUID references. Inherited policy can apply without a direct link.

    .EXAMPLE
    Invoke-MtTest -Id 'AD-GPOL-03'

    Lists targets without direct links for investigation, not as proof of missing policy.

    .LINK
    https://maester.dev/docs/tests/AD-GPOL-03
    #>
    [MaesterTest(
        Id                 = 'AD-GPOL-03',
        Title              = 'Direct GPO link coverage should be investigated',
        Product            = 'ad',
        Feature            = 'group-policy',
        Area               = 'infrastructure',
        ResourceType       = 'OrganizationalUnit',
        Severity           = 'Info',
        Mitre              = 'None',
        Service            = 'ActiveDirectory',
        Permission         = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author             = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.LinkContainers) { throw 'Domain or OU GPO link containers were not retrieved.' }
    $ous = @($state.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'organizationalUnit' })
    $domain = @($state.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'domainDNS' } | Select-Object -First 1)
    $sites = @($state.SiteContainers | Where-Object { @($_.ObjectClass) -contains 'site' })
    $sitesAvailable = $null -ne $state.SiteContainers
    $withoutLinks = { -not [regex]::IsMatch([string]$_.GpLink, '\{[0-9a-fA-F-]{36}\}') }
    $unlinkedOus = @($ous | Where-Object $withoutLinks)
    $unlinkedDomains = @($domain | Where-Object $withoutLinks)
    $unlinkedSites = @($sites | Where-Object $withoutLinks)
    $details = @(foreach ($target in @($unlinkedOus) + @($unlinkedDomains) + @($unlinkedSites)) {
            [pscustomobject]@{ Kind = @($target.ObjectClass)[-1]; DistinguishedName = $target.DistinguishedName }
        })
    $summary = if ($details.Count -eq 0) { 'No collected target lacks a direct GPO link. Review effective policy separately; a direct link is not proof of policy application.' }
    else { "$($details.Count) target(s) have no direct links. Investigate inherited policy; absence of a direct link is not proof of missing security policy." }
    $siteCount = if ($sitesAvailable) { $sites.Count } else { $null }
    $unlinkedSiteCount = if ($sitesAvailable) { $unlinkedSites.Count } else { $null }
    $totalWithoutLinks = if ($sitesAvailable) { $details.Count } else { $null }
    if (-not $sitesAvailable) { $summary = "Partial inventory: site data is unavailable. OU and domain metrics remain available; $($details.Count) known targets have no direct links. Review inherited policy separately." }
    $metrics = [ordered]@{ 'Total OUs' = $ous.Count; 'Unlinked OUs' = $unlinkedOus.Count; 'OUs with direct links' = $ous.Count - $unlinkedOus.Count; 'Total domains' = $domain.Count; 'Domains without direct links' = $unlinkedDomains.Count; 'Total sites' = $siteCount; 'Sites without direct links' = $unlinkedSiteCount; 'Targets without direct links' = $totalWithoutLinks }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics $metrics -Details @($details | Sort-Object Kind, DistinguishedName) -Properties Kind, DistinguishedName -Headers 'Target type', 'Distinguished name'
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
