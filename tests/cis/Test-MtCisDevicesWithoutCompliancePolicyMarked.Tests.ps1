Describe "CIS" -Tag "CIS.M365.4.1", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v7.0.0" {
    It "CIS.M365.4.1: Ensure devices without a compliance policy are marked 'not compliant'" {

        $result = Test-MtCisDevicesWithoutCompliancePolicyMarked

        if ($null -ne $result) {
            $result | Should -Be $true -Because "devices without a compliance policy are marked 'not compliant'"
        }
    }
}
