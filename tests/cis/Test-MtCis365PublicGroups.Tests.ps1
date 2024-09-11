Describe "CIS" -Tag "CIS 1.2.1", "L2", "CIS E3 Level 2", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 1.2.1 (L2) Ensure that only organizationally managed/approved public groups exist" {

        $result = Test-MtCis365PublicGroup

        if ($null -ne $result) {
            $result | Should -Be $true -Because "365 groups are private"
        }
    }
}