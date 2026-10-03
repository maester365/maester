Describe "Active Directory - GPO State" -Tag "AD", "AD.GPOState", "AD-GPOREP-19" {
    It "AD-GPOREP-19: No GPOs should contain a default password" {
        $result = Test-MtAdGpoDefaultPasswordFoundCount
        if ($null -ne $result) {
            $result | Should -Be $true -Because "default passwords in GPOs enable unauthorized access"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
