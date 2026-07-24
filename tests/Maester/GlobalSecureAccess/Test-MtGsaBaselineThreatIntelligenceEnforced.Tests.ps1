Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.1194: The baseline Global Secure Access security profile should enforce a threat-intelligence floor. See https://maester.dev/docs/tests/MT.1194" -Tag "MT.1194", "Preview" {
        $result = Test-MtGsaBaselineThreatIntelligenceEnforced

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the baseline is the only universal malware/phishing floor (covers non-client, token-gap, and unmatched traffic)."
        }
    }
}
