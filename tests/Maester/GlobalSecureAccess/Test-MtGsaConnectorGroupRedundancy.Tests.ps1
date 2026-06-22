Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX7: Microsoft Entra private network connector groups should have at least two active connectors. See https://maester.dev/docs/tests/MT.XXX7" -Tag "MT.XXX7", "Preview" {
        $result = Test-MtGsaConnectorGroupRedundancy

        if ($null -ne $result) {
            $result | Should -Be $true -Because "every in-use connector group needs at least two active connectors for high availability."
        }
    }
}
