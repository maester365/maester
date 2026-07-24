Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.1189: Groups assigned to Global Secure Access traffic forwarding profiles should not be nested. See https://maester.dev/docs/tests/MT.1189" -Tag "MT.1189", "Preview" {
        $result = Test-MtGsaForwardingProfileAssignmentNotNested

        if ($null -ne $result) {
            $result | Should -Be $true -Because "traffic forwarding profile assignment grants the profile to direct group members only; nested members are excluded."
        }
    }
}
