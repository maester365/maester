Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.1188: Entra Private Access applications should be covered by a Conditional Access policy that requires a managed device. See https://maester.dev/docs/tests/MT.1188" -Tag "MT.1188", "Preview" {
        $result = Test-MtGsaPrivateAccessAppCompliantDevice

        if ($null -ne $result) {
            $result | Should -Be $true -Because "every Private Access application should only be reachable from a compliant or hybrid joined device."
        }
    }
}
