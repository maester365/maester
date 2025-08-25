Describe "Maester/Entra" -Tag "Governance", "Entra", "Security" {
    It "MT.1068: Restrict non-admin users from creating tenants." -Tag "MT.1068" {
        $result = Test-MtTenantCreationRestricted
        $result | Should -Be $true -Because "Non-admin users should be restricted from creating new tenants to prevent shadow IT and security risks."
    }
}
