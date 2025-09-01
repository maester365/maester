Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.1", "CISA.MS.AAD.3.1", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.1: Phishing-resistant MFA SHALL be enforced for all users." {
        $result = Test-MtCisaPhishResistant

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled conditional access policy requires phishing-resistant MFA for all apps."
        }
    }
}
