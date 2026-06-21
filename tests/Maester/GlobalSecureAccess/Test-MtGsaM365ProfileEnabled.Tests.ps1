Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXXX: The Microsoft 365 traffic forwarding profile in Global Secure Access should be enabled. See https://maester.dev/docs/tests/MT.XXXX" -Tag "MT.XXXX", "Preview" {
        $result = Test-MtGsaM365ProfileEnabled

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the Microsoft 365 traffic forwarding profile unlocks source IP restoration, the Compliant Network signal, Universal Tenant Restrictions, and network access traffic logging."
        }
    }
}
