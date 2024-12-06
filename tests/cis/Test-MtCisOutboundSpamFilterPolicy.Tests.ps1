Describe "CIS" -Tag "CIS 2.1.6", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "2.1.6 (L1) Ensure Exchange Online Spam Policies are set to notify administrators (Only Checks Default Policy)" {

        $result = Test-MtCisOutboundSpamFilterPolicy

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the default Exchange Online Spam policy is set to notify administrators."
        }
    }
}