Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-20" {
    It "AD-GPOREP-20: GPO default password found details should be retrievable" {
        $result = Test-MtAdGpoDefaultPasswordFoundDetails
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
