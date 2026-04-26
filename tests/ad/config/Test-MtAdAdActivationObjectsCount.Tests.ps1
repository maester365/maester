Describe "Active Directory - Configuration" -Tag "AD", "AD.Config", "AD-CFG-09" {
    It "AD-CFG-09: AD activation objects count should be retrievable" {
        $result = Test-MtAdAdActivationObjectsCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "AD activation object data should be accessible"
        }
    }
}
