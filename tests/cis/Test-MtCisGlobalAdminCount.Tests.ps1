Describe "CIS" -Tag "CIS.M365.1.1.3", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.1.3: (L1) Ensure that between two and four global admins are designated" {

        $result = Test-MtCisGlobalAdminCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "only 2-4 Global Administrators exist"
        }
    }
}
