Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-01" {
    It "AD-CFG-01: Tombstone lifetime configuration should be retrievable" {
        $result = Test-MtAdTombstoneLifetimeConfig
        if ($null -ne $result) {
            $result | Should -Be $true -Because "tombstone lifetime data should be accessible"
        }
    }
}
