Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.XXX8: Groups assigned to Entra Private Access applications should not be nested. See https://maester.dev/docs/tests/MT.XXX8" -Tag "MT.XXX8", "Preview" {
        $result = Test-MtGsaPrivateAccessAppAssignmentNotNested

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enterprise app assignment grants access to direct group members only; nested members are excluded."
        }
    }
}
