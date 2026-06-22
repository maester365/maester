Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX12: Internet Access traffic should be filtered by a Global Secure Access filtering profile. See https://maester.dev/docs/tests/MT.XXX12" -Tag "MT.XXX12", "Preview" {
        $result = Test-MtGsaInternetAccessFilteringEnforced

        if ($null -ne $result) {
            $result | Should -Be $true -Because "acquiring internet traffic without any active filtering policy leaves egress unprotected."
        }
    }
}
