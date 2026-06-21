Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX2: Global Secure Access Conditional Access signaling should be enabled. See https://maester.dev/docs/tests/MT.XXX2" -Tag "MT.XXX2", "Preview" {
        $result = Test-MtGsaSignalingEnabled

        if ($null -ne $result) {
            $result | Should -Be $true -Because "signaling enables source IP restoration and the Compliant Network signal for token replay protection."
        }
    }
}
