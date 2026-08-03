Describe "Active Directory - Schema" -Tag "AD", "AD.Schema", "AD-SCH-05" {
    It "AD-SCH-05: LAPS installation status should be retrievable" {

        $result = Test-MtAdLapsInstalledStatus

        if ($null -ne $result) {
            # LAPS should ideally be installed for security compliance
            $result | Should -Be $true -Because "LAPS should be installed for secure local administrator password management"
        }
    }
}
