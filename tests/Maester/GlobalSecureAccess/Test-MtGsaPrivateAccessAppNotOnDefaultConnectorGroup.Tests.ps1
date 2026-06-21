Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX6: Entra Private Access applications should not use the Default connector group. See https://maester.dev/docs/tests/MT.XXX6" -Tag "MT.XXX6", "Preview" {
        $result = Test-MtGsaPrivateAccessAppNotOnDefaultConnectorGroup

        if ($null -ne $result) {
            $result | Should -Be $true -Because "new connectors auto-join Default, so serving apps from it risks routing production traffic through unintended connectors."
        }
    }
}
