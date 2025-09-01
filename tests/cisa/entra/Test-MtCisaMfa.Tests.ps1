Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.2", "CISA.MS.AAD.3.2", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.2: If phishing-resistant MFA has not been enforced, an alternative MFA method SHALL be enforced for all users." {
        $result = Test-MtCisaMfa

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled conditional access policy requires MFA for all apps."
        }
    }
}
