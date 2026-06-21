Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.XXX3: Entra Private Access applications should be covered by a Conditional Access policy that requires MFA. See https://maester.dev/docs/tests/MT.XXX3" -Tag "MT.XXX3", "Preview" {
        $result = Test-MtGsaPrivateAccessAppMfa

        if ($null -ne $result) {
            $result | Should -Be $true -Because "every Private Access application should be gated by multifactor authentication."
        }
    }
}
