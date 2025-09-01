Describe "CIS" -Tag "CIS.M365.2.1.1", "L2", "CIS E5 Level 2", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.2.1.1: (L2) Ensure Safe Links for Office Applications is Enabled (Only Checks Priority 0 Policy)" {

        $result = Test-MtCisSafeLink

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the priority 0 safe link policy matches CIS recommendations"
        }
    }
}
