Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.1", "CISA", "Security", "All", "Entra ID P1" {
    It "MS.AAD.3.1: Phishing-resistant MFA SHALL be enforced for all users." {
        $result = Test-MtCisaPhishResistant

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled conditional access policy requires phishing-resistant MFA for all apps."
        }
    }
}