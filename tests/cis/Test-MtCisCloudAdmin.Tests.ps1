Describe "CIS" -Tag "CIS 1.1.1", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v4.0.0" {
    It "1.1.1 (L1) Ensure Administrative accounts are cloud-only" {

        $result = Test-MtCisCloudAdmin

        if ($null -ne $result) {
            $result | Should -Be $true -Because "admin accounts are cloud-only"
        }
    }
}