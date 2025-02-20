param(
    [string]$DnsServerIpAddress
)

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.2.1", "CISA", "Security", "All" {
    It "MS.EXO.02.1: A list of approved IP addresses for sending mail SHALL be maintained." {
        $cisaSpfRestriction = Test-MtCisaSpfRestriction -DnsServerIpAddress $DnsServerIpAddress

        if ($null -ne $cisaSpfRestriction) {
            $cisaSpfRestriction | Should -Be $true -Because "SPF record should restrict authorized senders."
        }
    }
}