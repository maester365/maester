param(
    [string]$DnsServerIpAddress
)

Describe "CISA SCuBA" -Tag "MS.EXO", "MS.EXO.4.1", "CISA", "Security", "All" {
    It "MS.EXO.04.1: A DMARC policy SHALL be published for every second-level domain." {
        $cisaDmarcRecordExist = Test-MtCisaDmarcRecordExist -DnsServerIpAddress $DnsServerIpAddress

        if ($null -ne $cisaDmarcRecordExist) {
            $cisaDmarcRecordExist | Should -Be $true -Because "DMARC record should exist."
        }
    }
}