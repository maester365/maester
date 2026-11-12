BeforeAll {
    . (Join-Path $PSScriptRoot '../../../internal/services/ad/queries/Get-MtLdapReplicationPartitionState.ps1')
}
Describe 'Get-MtLdapReplicationPartitionState' {
    BeforeEach {
        $script:Unreadable = @()
        $script:LdapCalls = [System.Collections.Generic.List[object]]::new()
        function Invoke-MtLdapSearch {
            param($Connection,$SearchBase,$Scope,$Filter,$Attributes,$PageSize)
            $script:LdapCalls.Add([pscustomobject]@{
                SearchBase = $SearchBase
                Scope = $Scope
                Filter = $Filter
                Attributes = @($Attributes)
                PageSize = $PageSize
            }) | Out-Null
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
        $script:LdapCalls.Count | Should -Be $state.AdvertisedCount
        @($script:LdapCalls | Select-Object -ExpandProperty SearchBase | Sort-Object -Unique).Count | Should -Be $state.AdvertisedCount
        foreach ($call in $script:LdapCalls) {
            $call.Scope | Should -Be 'Base'
            $call.Filter | Should -Be '(objectClass=*)'
            $call.PageSize | Should -Be 0
            $call.Attributes | Should -Contain 'distinguishedName'
            $call.Attributes | Should -Contain 'objectClass'
        }
        foreach ($namingContext in $state.AdvertisedNamingContexts) {
            @($script:LdapCalls | Where-Object SearchBase -eq $namingContext).Count | Should -Be 1
        }
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
        @($script:LdapCalls | Where-Object SearchBase -eq 'DC=DomainDnsZones,DC=contoso,DC=com').Count | Should -Be 1
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
    It 'marks the core assessment unavailable when a mandatory RootDSE value is blank' {
        $script:RootDse.SchemaNamingContext = ''
        $state = Get-MtLdapReplicationPartitionState -Connection ([PSCustomObject]@{}) -RootDse $script:RootDse
        $state.CoreNamingContextAssessmentAvailable | Should -BeFalse
        $state.MissingCoreRootDseAttributes | Should -Contain 'SchemaNamingContext'
        $state.AdvertisedNamingContexts.Count | Should -Be 5
    }
}
