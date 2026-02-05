Describe "CIS" -Tag "CIS.M365.5.1.2.3", "L1", "CIS E3 Level 1", "CIS E3", "CIS E5 Level 1", "CIS E5", "CIS", "Security", "CIS M365 v5.0.0" {
    It "CIS.M365.5.1.2.3: Ensure 'Restrict non-admin users from creating tenants' is set to 'Yes'" {

        $result = Test-MtCisCreateTenantDisallowed

        if ($null -ne $result) {
            $result | Should -Be $true -Because "users are not allowed to register new tenants."
        }
    }
}