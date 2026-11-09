BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name @(
        'Test-MtAdSiteTotalCount', 'Test-MtAdSiteWithoutDcCount', 'Test-MtAdSiteWithoutSubnetCount',
        'Test-MtAdSubnetCatchAllCount', 'Test-MtAdSubnetIpv6Count', 'Test-MtAdSubnetNonInternalCount',
        'Test-MtAdSubnetFirstOctetCount', 'Test-MtAdOuOverlappingNameCount', 'Test-MtAdOuAtDomainRootCount',
        'Test-MtAdOuStaleCount', 'Test-MtAdOuEmptyCount', 'Test-MtAdPrinterTotalCount'
        'Get-MtAdStateCollection'
    )
}

Describe 'AD site, subnet, OU and printer checks with <Representation> state' -ForEach @(
    @{ Representation = 'Object' }
    @{ Representation = 'Hashtable' }
    @{ Representation = 'OrderedDictionary' }
) {
    BeforeEach {
        $script:detail = $null
        $fixture = [ordered]@{
            ReplicationSites = @([PSCustomObject]@{ Name = 'East, HQ'; DistinguishedName = 'CN=East\, HQ,CN=Sites,CN=Configuration,DC=example'; ObjectClass = @('site') })
            Subnets = @([PSCustomObject]@{ Name = '10.0.0.0/8'; DistinguishedName = 'CN=10.0.0.0/8,CN=Subnets'; SiteObject = 'cn=EAST\, HQ,cn=sites,cn=configuration,dc=example' })
            DomainControllers = @([PSCustomObject]@{ Name = 'dc1'; Site = 'East, HQ'; SiteDistinguishedName = 'cn=EAST\, HQ,cn=sites,dc=example' })
            Domain = [PSCustomObject]@{ DistinguishedName = 'DC=example' }
            OrganizationalUnits = @([PSCustomObject]@{ Name = 'Dev|Ops'; DistinguishedName = 'OU=Dev\,Ops,DC=example'; Modified = (Get-Date).AddYears(-7) })
            Users = @()
            Groups = @()
            Computers = @()
            Printers = @([PSCustomObject]@{ Name = 'P|1'; ServerName = 'server'; Location = 'Floor 1'; Description = 'Shared' })
        }
        $script:state = switch ($Representation) {
            'Object' { [PSCustomObject]$fixture }
            'Hashtable' { [hashtable]$fixture }
            'OrderedDictionary' { $fixture }
        }
        Mock Get-MtADDomainState -ModuleName Maester { $script:state }
        Mock Add-MtTestResultDetail -ModuleName Maester { param($Result, [switch]$Investigate) $script:detail = [PSCustomObject]@{ Text = $Result; Investigate = $Investigate.IsPresent } }
    }

    It 'uses the full escaped site DN case insensitively, and reports type and parent' {
        Test-MtAdSiteTotalCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'East, HQ \| site \| CN=Sites'
        $script:detail.Text | Should -Match 'CN=Sites,CN=Configuration'
        Test-MtAdSiteWithoutSubnetCount | Should -BeTrue
        $script:detail.Text | Should -Match 'sites with subnets: 1'
        $script:detail.Text | Should -Match 'orphaned subnets: 0'
    }

    It 'counts a subnet pointing to an unknown DN as orphaned instead of as a site association' {
        $script:state.Subnets[0].SiteObject = 'CN=Unknown,CN=Sites,CN=Configuration,DC=example'
        Test-MtAdSiteWithoutSubnetCount | Should -BeFalse
        $script:detail.Text | Should -Match 'sites with subnets: 0'
        $script:detail.Text | Should -Match 'orphaned subnets: 1'
        $script:detail.Text | Should -Match 'CN=Unknown'
        $script:state.Subnets[0].SiteObject = $null
        Test-MtAdSiteWithoutSubnetCount | Should -BeFalse
        $script:detail.Text | Should -Match 'orphaned subnets: 1'
    }

    It 'does not pass a missing category or an incomplete DC site assignment' {
        $script:state.Subnets = $null
        { Test-MtAdSiteWithoutSubnetCount } | Should -Throw '*Subnets*unavailable*'
        if ($script:state -is [System.Collections.IDictionary]) { $script:state.Remove('Subnets') }
        else { $script:state.PSObject.Properties.Remove('Subnets') }
        { Test-MtAdSiteWithoutSubnetCount } | Should -Throw '*Subnets*unavailable*'
        $script:state.DomainControllers[0].Site = $null
        { Test-MtAdSiteWithoutDcCount } | Should -Throw '*missing Site or SiteDistinguishedName metadata*'
    }

    It 'accepts a retrieved empty subnet collection but not a missing one' {
        $script:state.Subnets = @()
        Test-MtAdSiteWithoutSubnetCount | Should -BeFalse
        $script:detail.Text | Should -Match 'subnets: 0'
    }

    It 'allows intentionally DC-less sites but flags uncovered names by default' {
        $script:state.DomainControllers = @()
        Test-MtAdSiteWithoutDcCount | Should -BeFalse
        Test-MtAdSiteWithoutDcCount -AllowedSitesWithoutDcs @('East, HQ') | Should -BeTrue
    }

    It 'validates each CIDR and inventories IPv6, broad IPv4 and non-RFC1918 prefixes' {
        $script:state.Subnets += [PSCustomObject]@{ Name = '2001:db8::/64'; DistinguishedName = 'CN=v6'; SiteObject = $null }
        $script:state.Subnets += [PSCustomObject]@{ Name = '100.64.0.0/10'; DistinguishedName = 'CN=shared'; SiteObject = $null }
        Test-MtAdSubnetCatchAllCount | Should -BeTrue
        $script:detail.Text | Should -Match '10.0.0.0/8'
        Test-MtAdSubnetIpv6Count | Should -BeTrue
        $script:detail.Text | Should -Match '2001:db8::/64'
        Test-MtAdSubnetNonInternalCount | Should -BeTrue
        $script:detail.Text | Should -Match '100.64.0.0/10'
        $script:detail.Text | Should -Match 'does not necessarily mean public'
        Test-MtAdSubnetFirstOctetCount | Should -BeTrue
        $script:detail.Text | Should -Match '10.0.0.0/8'
        $script:state.Subnets += [PSCustomObject]@{ Name = '300.1.2.0/24'; DistinguishedName = 'CN=invalid' }
        { Test-MtAdSubnetFirstOctetCount } | Should -Throw '*Invalid subnet address*'
        $script:state.Subnets[-1].Name = '192.168.0.0/33'
        { Test-MtAdSubnetIpv6Count } | Should -Throw '*Invalid subnet prefix*'
    }

    It 'treats repeated OU names as naming hygiene, not duplicate DNs, and escapes report values' {
        $script:state.OrganizationalUnits += [PSCustomObject]@{ Name = 'Dev|Ops'; DistinguishedName = 'OU=Dev|Ops,OU=Other,DC=example'; Modified = Get-Date }
        Test-MtAdOuOverlappingNameCount | Should -BeFalse
        $script:detail.Text | Should -Match 'Dev&#124;Ops'
        $script:detail.Text | Should -Not -Match '<br>'
    }

    It 'lists root OUs, validates missing modification dates and honors the calendar-year threshold' {
        Test-MtAdOuAtDomainRootCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        Test-MtAdOuStaleCount -MaximumAgeYears 5 | Should -BeTrue
        $script:detail.Text | Should -Match '1 OU\(s\)'
        Test-MtAdOuStaleCount -MaximumAgeYears 10 | Should -BeTrue
        $script:detail.Text | Should -Match '0 OU\(s\)'
        $script:state.OrganizationalUnits[0].Modified = $null
        { Test-MtAdOuStaleCount } | Should -Throw '*no modification date*'
    }

    It 'counts only selected direct child types and never claims a truly empty OU' {
        Test-MtAdOuEmptyCount | Should -BeTrue
        $script:detail.Text | Should -Match 'without a direct visible'
        $script:state.OrganizationalUnits += [PSCustomObject]@{ Name = 'Child'; DistinguishedName = 'OU=Child,OU=Dev\,Ops,DC=example'; Modified = Get-Date }
        Test-MtAdOuEmptyCount | Should -BeTrue
        $script:detail.Text | Should -Match '1 OU\(s\)'
    }

    It 'reports printer name, server, location and description for review' {
        Test-MtAdPrinterTotalCount | Should -BeTrue
        $script:detail.Investigate | Should -BeTrue
        $script:detail.Text | Should -Match 'P&#124;1 \| server \| Floor 1 \| Shared'
    }

    It 'accepts retrieved empty subnet and printer collections as inventories' {
        $script:state.Subnets = @()
        foreach ($command in 'Test-MtAdSubnetCatchAllCount', 'Test-MtAdSubnetIpv6Count', 'Test-MtAdSubnetNonInternalCount', 'Test-MtAdSubnetFirstOctetCount') {
            & $command | Should -BeTrue
            $script:detail.Investigate | Should -BeTrue
        }
        $script:state.Printers = @()
        Test-MtAdPrinterTotalCount | Should -BeTrue
        $script:detail.Text | Should -Match '0 published printer'
    }

    It 'preserves an empty collection as a non-null array value' {
        $script:state.Subnets = @()
        $collection = Get-MtAdStateCollection -State $script:state -Name Subnets
        ($null -eq $collection) | Should -BeFalse
        $collection.Count | Should -Be 0
    }

    It 'retains errors for null inventory instead of turning failed collection into an empty result' {
        $script:state.OrganizationalUnits = $null
        { Test-MtAdOuOverlappingNameCount } | Should -Throw '*OrganizationalUnits data is unavailable*'
        $script:state.ReplicationSites = $null
        { Test-MtAdSiteTotalCount } | Should -Throw '*ReplicationSites data is unavailable*'
        $script:state.Subnets = $null
        { Test-MtAdSubnetCatchAllCount } | Should -Throw '*Subnets data is unavailable*'
        $script:state.Printers = $null
        { Test-MtAdPrinterTotalCount } | Should -Throw '*Printers data is unavailable*'
    }
}
