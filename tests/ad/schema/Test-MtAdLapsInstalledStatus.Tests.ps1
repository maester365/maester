Describe "Active Directory - Schema" -Tag "AD", "AD.Schema", "AD-SCH-05" {
    It "AD-SCH-05: LAPS should be installed in Active Directory" {

        $result = Test-MtAdLapsInstalledStatus

        if ($null -ne $result) {
            # LAPS should ideally be installed for security compliance
            $result | Should -Be $true -Because "LAPS should be installed for secure local administrator password management"
        } else {
            Set-ItResult -Skipped -Because "Active Directory data could not be retrieved"
        }
    }
}
