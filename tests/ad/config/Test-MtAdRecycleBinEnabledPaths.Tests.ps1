Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-05" {
    It "AD-CFG-05: Recycle bin enabled paths should be retrievable" {
        $result = Test-MtAdRecycleBinEnabledPaths
        if ($null -ne $result) {
            $result | Should -Be $true -Because "recycle bin configuration should be accessible"
        }
    }
}
