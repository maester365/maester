function Get-MtAdSiteSubnetOverview {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)] $State,
        [switch] $Sites,
        [switch] $Subnets,
        [switch] $Controllers
    )

    foreach ($category in @(@{ Required = $Sites; Name = 'ReplicationSites' }, @{ Required = $Subnets; Name = 'Subnets' }, @{ Required = $Controllers; Name = 'DomainControllers' })) {
        if ($category.Required -and ($null -eq $State -or $null -eq $State.PSObject.Properties[$category.Name] -or $null -eq $State.($category.Name))) {
            throw "Active Directory $($category.Name) data is unavailable."
        }
    }

    $siteEntries = if ($Sites) { @($State.ReplicationSites) } else { @() }
    $subnetEntries = if ($Subnets) { @($State.Subnets) } else { @() }
    $siteByDn = @{}
    foreach ($site in $siteEntries) {
        if ([string]::IsNullOrWhiteSpace($site.DistinguishedName) -or [string]::IsNullOrWhiteSpace($site.Name)) {
            throw 'A replication site has missing Name or DistinguishedName metadata.'
        }
        $siteByDn[[string]$site.DistinguishedName] = $site
    }

    $withSubnet = @{}
    $orphaned = @($subnetEntries | Where-Object { [string]::IsNullOrWhiteSpace($_.SiteObject) })
    foreach ($subnet in $subnetEntries) {
        if ([string]::IsNullOrWhiteSpace($subnet.Name) -or [string]::IsNullOrWhiteSpace($subnet.DistinguishedName)) {
            throw 'A subnet has missing Name or DistinguishedName metadata.'
        }
        if (-not [string]::IsNullOrWhiteSpace($subnet.SiteObject) -and $Sites) {
            if ($siteByDn.ContainsKey([string]$subnet.SiteObject)) {
                $withSubnet[[string]$subnet.SiteObject] = $true
            } else {
                $orphaned += $subnet
            }
        }
    }

    $withDc = @{}
    if ($Controllers) {
        foreach ($dc in @($State.DomainControllers)) {
            if ([string]::IsNullOrWhiteSpace($dc.Site) -or [string]::IsNullOrWhiteSpace($dc.SiteDistinguishedName)) {
                throw 'A domain controller has missing Site or SiteDistinguishedName metadata; site coverage cannot be determined.'
            }
            if (-not $siteByDn.ContainsKey([string]$dc.SiteDistinguishedName)) {
                throw "Domain controller site DN '$($dc.SiteDistinguishedName)' does not match any retrieved replication site."
            }
            if ($dc.Site -ine $siteByDn[[string]$dc.SiteDistinguishedName].Name) {
                throw "Domain controller site name '$($dc.Site)' does not match the site at '$($dc.SiteDistinguishedName)'."
            }
            $withDc[[string]$dc.SiteDistinguishedName] = $true
        }
    }

    return [PSCustomObject]@{
        Sites = $siteEntries
        Subnets = $subnetEntries
        SitesWithSubnets = @($siteEntries | Where-Object { $withSubnet.ContainsKey([string]$_.DistinguishedName) })
        SitesWithoutSubnets = @($siteEntries | Where-Object { -not $withSubnet.ContainsKey([string]$_.DistinguishedName) })
        OrphanedSubnets = @($orphaned)
        SitesWithoutDcs = @($siteEntries | Where-Object { -not $withDc.ContainsKey([string]$_.DistinguishedName) })
    }
}
