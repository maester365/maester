Describe "CIS" -Tag "CIS.M365.1.3.3", "L2", "CIS E3 Level 2", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.3.3: (L2) Ensure 'External sharing' of calendars is not available" {

        $result = Test-MtCisCalendarSharing

        if ($null -ne $result) {
            $result | Should -Be $true -Because "calendar sharing is disabled."
        }
    }
}
