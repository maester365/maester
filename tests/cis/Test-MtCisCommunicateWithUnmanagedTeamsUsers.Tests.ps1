Describe "CIS" -Tag "All", "Security", "CIS", "CIS M365 v4.0.0" {
    It "CIS 8.2.2 (L1) Ensure communication with unmanaged Teams users is disabled" -Tag "CIS 8.2.2", "CIS E3 Level 1" {
        $result = Test-MtCisCommunicateWithUnmanagedTeamsUsers
        if ($null -ne $result) {
            $result | Should -Be $true -Because "Communication with unmanaged Teams users is disabled."
        }
    }
}