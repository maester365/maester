Describe "CIS" -Tag "All", "Security", "CIS", "CIS M365 v4.0.0" {
    It "CIS 8.2.4 (L1) Ensure communication with Skype users is disabled" -Tag "CIS 8.2.4", "CIS E3 Level 1" {
        $result = Test-MtCisCommunicateWithSkypeUsers
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Communication with Skype users is disabled."
        }
    }
}