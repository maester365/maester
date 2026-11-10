BeforeAll {
    . (Join-Path $PSScriptRoot '../../../internal/services/ad/queries/Get-MtLdapReplicationPartitionState.ps1')
}
Describe 'Get-MtLdapReplicationPartitionState' {
    BeforeEach {
        $script:Unreadable = @()
        function Invoke-MtLdapSearch {
            param($Connection,$SearchBase,$Scope,$Filter,$Attributes,$PageSize)
            if ($SearchBase -in $script:Unreadable) { throw "cannot read $SearchBase" }
            [PSCustomObject]@{ DistinguishedName = $SearchBase; objectClass = 'top' }
        }
        $script:RootDse = [PSCustomObject]@{
            DnsHostName = 'dc01.contoso.com'
            DefaultNamingContext = 'DC=contoso,DC=com'
            RootDomainNamingContext = 'DC=contoso,DC=com'
            ConfigurationNamingContext = 'CN=Configuration,DC=contoso,DC=com'
            SchemaNamingContext = 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
            NamingContexts = @('DC=contoso,DC=com','CN=Configuration,DC=contoso,DC=com','CN=Schema,CN=Configuration,DC=contoso,DC=com','DC=DomainDnsZones,DC=contoso,DC=com','DC=ForestDnsZones,DC=contoso,DC=com')
        }
    }
    It 'reports three mandatory core contexts and two advertised DNS application partitions' {
        $state = Get-MtLdapReplicationPartitionState -Connection ([PSCustomObject]@{}) -RootDse $script:RootDse
        $state.AdvertisedCount | Should -Be 5
        $state.ReadableCount | Should -Be 5
        $state.UnreadableCount | Should -Be 0
        $state.MissingExpectedCount | Should -Be 0
        $state.ExpectedCoreNamingContexts.Count | Should -Be 3
        $state.AdvertisedDnsApplicationPartitionCount | Should -Be 2
    }
    It 'preserves additional application partitions without failing the core set' {
        $script:RootDse.NamingContexts += 'DC=AppPartition,DC=contoso,DC=com'
        $state = Get-MtLdapReplicationPartitionState -Connection ([PSCustomObject]@{}) -RootDse $script:RootDse
        $state.AdvertisedCount | Should -Be 6
        $state.MissingExpectedCount | Should -Be 0
    }
    It 'reports an advertised but unreadable partition' {
        $script:Unreadable = @('DC=DomainDnsZones,DC=contoso,DC=com')
        $state = Get-MtLdapReplicationPartitionState -Connection ([PSCustomObject]@{}) -RootDse $script:RootDse
        $state.UnreadableCount | Should -Be 1
        $state.PartitionResults | Where-Object { -not $_.Readable } | Select-Object -ExpandProperty NamingContext | Should -Be 'DC=DomainDnsZones,DC=contoso,DC=com'
    }
    It 'does not fail when a DNS application partition is not hosted by the assessed DC' {
        $script:RootDse.NamingContexts = @($script:RootDse.NamingContexts | Where-Object { $_ -notlike 'DC=ForestDnsZones,*' })
        $state = Get-MtLdapReplicationPartitionState -Connection ([PSCustomObject]@{}) -RootDse $script:RootDse
        $state.MissingExpectedCount | Should -Be 0
        $state.UnreadableCount | Should -Be 0
        ($state.DnsApplicationPartitions | Where-Object Name -eq 'ForestDnsZones').Status | Should -Be 'NotAdvertisedOnAssessedDc'
    }
    It 'reports a missing mandatory core naming context separately from readability' {
        $script:RootDse.NamingContexts = @($script:RootDse.NamingContexts | Where-Object { $_ -notlike 'CN=Schema,*' })
        $state = Get-MtLdapReplicationPartitionState -Connection ([PSCustomObject]@{}) -RootDse $script:RootDse
        $state.MissingExpectedCount | Should -Be 1
        $state.MissingExpectedNamingContexts | Should -Contain 'CN=Schema,CN=Configuration,DC=contoso,DC=com'
        $state.UnreadableCount | Should -Be 0
    }
}