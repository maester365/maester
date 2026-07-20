Describe "Active Directory - Security Accounts" -Tag "AD", "AD.Security", "AD-KRBTGT-03" {
    It "AD-KRBTGT-03: KRBTGT should have standard UAC settings (disabled account)" {

        $result = Test-MtAdKrbtgtNonStandardUacCount

        if ($null -ne $result) {
            $result | Should -Be $true -Because "KRBTGT account should have standard UAC settings (514 = disabled normal account)"
        }
    }
}
