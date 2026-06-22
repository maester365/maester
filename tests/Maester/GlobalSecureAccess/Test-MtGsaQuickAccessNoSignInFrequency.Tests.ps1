Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.XXX14: The Quick Access app should not be subject to a sign-in frequency Conditional Access control. See https://maester.dev/docs/tests/MT.XXX14" -Tag "MT.XXX14", "Preview" {
        $result = Test-MtGsaQuickAccessNoSignInFrequency

        if ($null -ne $result) {
            $result | Should -Be $true -Because "sign-in frequency on Quick Access re-triggers authentication on Private DNS lookups, causing unexpected prompts."
        }
    }
}
