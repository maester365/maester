# Legacy Pester fixture: a custom test that calls an exported built-in check function
# directly. Unsupported in 3.0 (design section 8): the function loses its connection guard
# and outer try/catch, so on a tenant without the service it throws instead of skipping.
# The supported form is Invoke-MtTest -Id MT.1006. Needs a Graph connection to pass or fail.
Describe "Contoso direct calls" -Tag "Contoso", "NeedsTenant" {
    It "CONTOSO.6001: Admins require MFA (direct call to a built-in)" -Tag "CONTOSO.6001", "NeedsTenant" {
        Test-MtCaMfaForAdmin | Should -Be $true -Because "admins must use MFA"
    }
}
