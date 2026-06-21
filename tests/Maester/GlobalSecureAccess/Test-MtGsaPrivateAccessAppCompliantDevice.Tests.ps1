Describe "Maester/Entra" -Tag "Maester", "Entra", "CA" {
    It "MT.XXX4: Entra Private Access applications should be covered by a Conditional Access policy that requires a managed device. See https://maester.dev/docs/tests/MT.XXX4" -Tag "MT.XXX4", "Preview" {
        $result = Test-MtGsaPrivateAccessAppCompliantDevice

        if ($null -ne $result) {
            $result | Should -Be $true -Because "every Private Access application should only be reachable from a compliant or hybrid joined device."
        }
    }
}
