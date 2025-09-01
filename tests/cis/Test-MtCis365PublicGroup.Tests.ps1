Describe "CIS" -Tag "CIS.M365.1.2.1", "L2", "CIS E3 Level 2", "CIS E3", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.1.2.1: (L2) Ensure that only organizationally managed/approved public groups exist" {

        $result = Test-MtCis365PublicGroup

        if ($null -ne $result) {
            $result | Should -Be $true -Because "365 groups are private"
        }
    }
}
