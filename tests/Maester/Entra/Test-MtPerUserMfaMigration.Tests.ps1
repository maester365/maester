Describe "Maester/Entra" -Tag "Maester", "Entra", "Authentication" {
    It "MT.1123: Legacy per-user MFA should be migrated to authentication methods policy. See https://maester.dev/docs/tests/MT.1123" -Tag "MT.1123" {
        $result = Test-MtPerUserMfaMigration

        if ($null -ne $result) {
            $result | Should -Be $true -Because "the tenant should have completed the migration from legacy per-user MFA to the authentication methods policy"
        }
    }
}
