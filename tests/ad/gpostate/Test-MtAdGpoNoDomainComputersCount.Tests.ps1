Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-06" {
    It "AD-GPOREP-06: GPOs without domain computers count should be retrievable" {
        $result = Test-MtAdGpoNoDomainComputersCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "GPO permissions data should be accessible"
        }
    }
}
