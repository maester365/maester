Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.XXX9: A Compliant Network Conditional Access policy should be active with the minimum required exclusions. See https://maester.dev/docs/tests/MT.XXX9" -Tag "MT.XXX9", "Preview" {
        $result = Test-MtGsaCompliantNetworkPolicy

        if ($null -ne $result) {
            $result | Should -Be $true -Because "token replay protection requires an enabled Compliant Network block policy that does not break Intune enrollment."
        }
    }
}
