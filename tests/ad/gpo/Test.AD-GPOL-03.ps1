function Test-MtAdGpoUnlinkedTargetCount {
    <#
    .SYNOPSIS
    Inventories direct GPO link coverage for investigation.
    .DESCRIPTION
    Counts linked and unlinked OUs and lists OUs, the domain root and sites without
    direct GUID references. Inherited policy can apply without a direct link.
    #>
    [MaesterTest(
        Id = 'AD-GPOL-03', Title = 'Direct GPO link coverage should be investigated',
        Product = 'ad', Feature = 'group-policy', Area = 'infrastructure',
        ResourceType = 'OrganizationalUnit', Severity = 'Info', Mitre = 'None', Service = 'ActiveDirectory',
        Permission = ('ActiveDirectory:Ldap:groupPolicyContainer.gPCFileSysPath:ReadProperty', 'ActiveDirectory:File:SYSVOL:Read'),
        Author = 'soulemike'
    )]
    [CmdletBinding()]
    [OutputType([bool])]
    param()
    $state = Get-MtADGpoState
    if ($null -eq $state -or $null -eq $state.LinkContainers -or $null -eq $state.SiteContainers) { throw 'Domain, OU or site GPO link containers were not retrieved.' }
    $ous = @($state.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'organizationalUnit' })
    $domain = @($state.LinkContainers | Where-Object { @($_.ObjectClass) -contains 'domainDNS' } | Select-Object -First 1)
    $sites = @($state.SiteContainers | Where-Object { @($_.ObjectClass) -contains 'site' })
    $withoutLinks = { -not [regex]::IsMatch([string]$_.GpLink, '\{[0-9a-fA-F-]{36}\}') }
    $unlinkedOus = @($ous | Where-Object $withoutLinks)
    $unlinkedDomains = @($domain | Where-Object $withoutLinks)
    $unlinkedSites = @($sites | Where-Object $withoutLinks)
    $details = @(foreach ($target in @($unlinkedOus) + @($unlinkedDomains) + @($unlinkedSites)) {
            [pscustomobject]@{ Kind = @($target.ObjectClass)[-1]; DistinguishedName = $target.DistinguishedName }
        })
    $summary = if ($details.Count -eq 0) { 'No collected target lacks a direct GPO link. Review effective policy separately; a direct link is not proof of policy application.' }
    else { "$($details.Count) target(s) have no direct links. Investigate inherited policy; absence of a direct link is not proof of missing security policy." }
    $metrics = [ordered]@{ 'Total OUs' = $ous.Count; 'Unlinked OUs' = $unlinkedOus.Count; 'OUs with direct links' = $ous.Count - $unlinkedOus.Count; 'Total domains' = $domain.Count; 'Domains without direct links' = $unlinkedDomains.Count; 'Total sites' = $sites.Count; 'Sites without direct links' = $unlinkedSites.Count; 'Targets without direct links' = $details.Count }
    $result = Format-MtAdGpoResult -Summary $summary -Metrics $metrics -Details @($details | Sort-Object Kind, DistinguishedName) -Properties Kind, DistinguishedName -Headers 'Target type', 'Distinguished name'
    Add-MtTestResultDetail -Result $result -Investigate
    return $true
}
