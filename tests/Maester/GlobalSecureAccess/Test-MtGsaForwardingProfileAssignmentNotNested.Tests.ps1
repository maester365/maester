Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX5: Groups assigned to Global Secure Access traffic forwarding profiles should not be nested. See https://maester.dev/docs/tests/MT.XXX5" -Tag "MT.XXX5", "Preview" {
        $result = Test-MtGsaForwardingProfileAssignmentNotNested

        if ($null -ne $result) {
            $result | Should -Be $true -Because "traffic forwarding profile assignment grants the profile to direct group members only; nested members are excluded."
        }
    }
}
