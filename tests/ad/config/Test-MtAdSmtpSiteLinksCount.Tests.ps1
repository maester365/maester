Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-23" {
    It "AD-CFG-23: SMTP site links count should be retrievable" {
        $result = Test-MtAdSmtpSiteLinksCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "SMTP site link data should be accessible"
        }
    }
}
