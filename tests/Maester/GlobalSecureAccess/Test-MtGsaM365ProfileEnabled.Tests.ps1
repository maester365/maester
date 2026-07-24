Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.1187: The Microsoft 365 traffic forwarding profile in Global Secure Access should be enabled. See https://maester.dev/docs/tests/MT.1187" -Tag "MT.1187", "Preview" {
        $result = Test-MtGsaM365ProfileEnabled

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the Microsoft 365 traffic forwarding profile unlocks source IP restoration, the Compliant Network signal, Universal Tenant Restrictions, and network access traffic logging."
        }
    }
}
