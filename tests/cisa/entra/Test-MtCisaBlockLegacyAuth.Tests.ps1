Describe "CISA" -Tag "MS.AAD", "MS.AAD.1.1", "CISA", "CISA.MS.AAD.1.1", "Security", "MS.AAD", "Entra ID P1" {
    It "CISA.MS.AAD.1.1: Legacy authentication SHALL be blocked." {
        $result = Test-MtCisaBlockLegacyAuth

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled policy for all users blocking legacy auth access shall exist."
        }
    }
}
