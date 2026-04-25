Describe "Active Directory - Computer Objects" -Tag "AD", "AD.Computer", "AD-COMP-08" {
    It "AD-COMP-08: Computer per OU average should be retrievable" {

        $result = Test-MtAdComputerPerOUAverage

        if ($null -ne $result) {
            $result | Should -Be $true -Because "per-OU average data should be accessible"
        }
    }
}
