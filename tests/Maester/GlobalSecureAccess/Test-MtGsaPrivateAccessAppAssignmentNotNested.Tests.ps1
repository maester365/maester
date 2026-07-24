Describe "Maester/Entra" -Tag "Maester", "Entra" {
    It "MT.1192: Groups assigned to Entra Private Access applications should not be nested. See https://maester.dev/docs/tests/MT.1192" -Tag "MT.1192", "Preview" {
        $result = Test-MtGsaPrivateAccessAppAssignmentNotNested

        if ($null -ne $result) {
            $result | Should -Be $true -Because "enterprise app assignment grants access to direct group members only; nested members are excluded."
        }
    }
}
