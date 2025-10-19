Describe "CISA" -Tag "MS.AAD", "MS.AAD.3.3", "CISA.MS.AAD.3.3", "CISA", "Security", "Entra ID P1" {
    It "CISA.MS.AAD.3.3: If Microsoft Authenticator is enabled, it SHALL be configured to show login context information." {
        $result = Test-MtCisaAuthenticatorContext

        if ($null -ne $result) {
            $result | Should -Be $true -Because "Microsoft Authenticator is configured to show login context information."
        }
    }
}
