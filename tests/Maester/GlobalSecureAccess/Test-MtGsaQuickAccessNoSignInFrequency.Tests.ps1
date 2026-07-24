Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.1195: The Quick Access app should not be subject to a sign-in frequency Conditional Access control. See https://maester.dev/docs/tests/MT.1195" -Tag "MT.1195", "Preview" {
        $result = Test-MtGsaQuickAccessNoSignInFrequency

        if ($null -ne $result) {
            $result | Should -Be $true -Because "sign-in frequency on Quick Access re-triggers authentication on Private DNS lookups, causing unexpected prompts."
        }
    }
}
