Describe "CIS" -Tag "CIS 1.2.2", "L1", "CIS E3 Level 1", "CIS E3", "CIS", "Security", "All", "CIS M365 v3.1.0" {
    It "CIS 1.2.2 (L1) Ensure sign-in to shared mailboxes is blocked" {

        $result = Test-MtCisSharedMailboxSignIn

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Sign ins are blocked for shared mailboxes"
        }
    }
}