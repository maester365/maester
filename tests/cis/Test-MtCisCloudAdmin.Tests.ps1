Describe "CIS" -Tag "CIS 1.1.1", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 1.1.1 (L1) Ensure Administrative accounts are separate and cloud-only" {

        $result = Test-MtCisCloudAdmin

        if ($null -ne $result) {
            $result | Should -Be $true -Because "admin accounts are separate and cloud-only"
        }
    }
}