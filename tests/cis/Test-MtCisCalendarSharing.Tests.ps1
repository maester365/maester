Describe "CIS" -Tag "CIS 1.3.3", "L2", "CIS E3 Level 2", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 1.3.3 (L2) Ensure 'External sharing' of calendars is not available" {

        $result = Test-MtCisCalendarSharing

        if ($null -ne $result) {
            $result | Should -Be $true -Because "calendar sharing is disabled."
        }
    }
}