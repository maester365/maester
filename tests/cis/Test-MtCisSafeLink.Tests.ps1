Describe "CIS" -Tag "CIS 2.1.1", "L2", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "2.1.1 (L2) Ensure Safe Links for Office Applications is Enabled" {

        $result = Test-MtCisSafeLink

        if ($null -ne $result) {
            $result | Should -Be $true -Because "safe links office applications are Enabled"
        }
    }
}