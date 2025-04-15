Describe "CIS" -Tag "CIS 2.1.12", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v4.0.0" {
    It "CIS 2.1.12 (L1) Ensure the connection filter IP allow list is not used (Only Checks Default Policy)" {

        $result = Test-MtCisHostedConnectionFilterPolicy

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the IP Allow List is empty."
        }
    }
}