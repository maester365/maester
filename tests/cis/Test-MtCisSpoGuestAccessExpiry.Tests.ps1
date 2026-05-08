Describe "CIS" -Tag "CIS.M365.7.2.9", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS",  "CIS M365 v6.0.1" {
    It "CIS.M365.7.2.9: Ensure guest access to a site or OneDrive will expire automatically" {

        $result = Test-MtCisSpoGuestAccessExpiry

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Guest access to a site or OneDrive will expire automatically"
        }
    }
}
