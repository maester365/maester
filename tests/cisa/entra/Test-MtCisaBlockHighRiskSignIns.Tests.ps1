Describe "CISA SCuBA" -Tag "MS.AAD", "MS.AAD.2.3", "CISA", "Security", "All", "Entra ID P2" {
    It "MS.AAD.2.3: Sign-ins detected as high risk SHALL be blocked." {
        $result = Test-MtCisaBlockHighRiskSignIn

        if ($null -ne $result) {
            $result | Should -Be $true -Because "an enabled policy for all users blocking high risk sign-ins shall exist."
        }
    }
}