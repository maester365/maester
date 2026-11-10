BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force }
Describe 'AD DNS zone authorization' {
    It 'keeps the feature read-only' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapDnsZoneAuthorization.ps1" -Raw
        $source | Should -Not -Match 'AddRequest|ModifyRequest|DeleteRequest|New-DnsServerResourceRecord|Remove-DnsServerResourceRecord'
    }
    It 'declares both native tests' {
        Test-Path "$PSScriptRoot/../../../tests/ad/dns/Test.AD-DNS-20.ps1" | Should -BeTrue
        Test-Path "$PSScriptRoot/../../../tests/ad/dns/Test.AD-DNS-21.ps1" | Should -BeTrue
    }
    It 'normalizes wrapped and array schema GUID values before conversion' {
        $source=Get-Content "$PSScriptRoot/../../internal/services/ad/queries/Get-MtLdapDnsZoneAuthorization.ps1" -Raw
        $source | Should -Match 'schemaGuidRaw'
        $source | Should -Match 'single-item object array'
        $source | Should -Match 'Object\[16\]'
        $source | Should -Match 'expected 16'
    }
}