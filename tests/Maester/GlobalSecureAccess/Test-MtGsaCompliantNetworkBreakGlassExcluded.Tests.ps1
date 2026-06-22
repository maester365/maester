Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.XXX10: Break-glass accounts should be excluded from the Compliant Network Conditional Access policy. See https://maester.dev/docs/tests/MT.XXX10" -Tag "MT.XXX10", "Preview" {
        $result = Test-MtGsaCompliantNetworkBreakGlassExcluded

        if ($null -ne $result) {
            $result | Should -Be $true -Because "a Compliant Network block policy must never lock out emergency access accounts."
        }
    }
}
