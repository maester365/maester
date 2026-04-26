Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-24" {
    It "AD-CFG-24: IP site links count should be retrievable" {
        $result = Test-MtAdIpSiteLinksCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "IP site link data should be accessible"
        }
    }
}
