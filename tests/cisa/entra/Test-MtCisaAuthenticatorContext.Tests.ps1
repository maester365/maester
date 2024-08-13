Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.3.3", "CISA", "Security", "All", "Entra ID P1" {
    It "MS.AAD.3.3: If phishing-resistant MFA has not been enforced and Microsoft Authenticator is enabled, it SHALL be configured to show login context information." {
        $result = Test-MtCisaAuthenticatorContext

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft Authenticator is configured to show login context information."
        }
    }
}