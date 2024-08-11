Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.1.1", "CISA", "Security", "All", "MS.AAD", "Entra ID P1" {
    It "MS.AAD.1.1: Legacy authentication SHALL be blocked." {
        $result = Test-MtCisaBlockLegacyAuth

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled policy for all users blocking legacy auth access shall exist."
        }
    }
}