Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.2", "CISA", "Security", "All", "Entra ID P1" {
    It "MS.AAD.3.2: If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users." {
        $result = Test-MtCisaMfa

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled conditional access policy requires MFA for all apps."
        }
    }
}