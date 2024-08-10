Describe "CIS" -Tag "CIS 1.1.1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All" {
    It "CIS 1.1.1: Ensure Administrative accounts are separate and cloud-only" {

        $result = Test-MtCisCloudAdmin

        if($null -ne $result) {
            $result | Should -Be $true -Because "admin accounts are separate and cloud-only"
        }
    }
}