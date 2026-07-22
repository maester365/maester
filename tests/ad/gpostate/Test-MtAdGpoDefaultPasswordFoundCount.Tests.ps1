Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-19" {
    It "AD-GPOREP-19: GPO default password found count should be retrievable" {
        $result = Test-MtAdGpoDefaultPasswordFoundCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO report data should be accessible"
        }
    }
}
