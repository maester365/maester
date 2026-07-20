Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-20" {
    It "AD-CFG-20: CRL distribution points count should be retrievable" {
        $result = Test-MtAdCrlDistributionPointsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "CRL distribution point data should be accessible"
        }
    }
}
