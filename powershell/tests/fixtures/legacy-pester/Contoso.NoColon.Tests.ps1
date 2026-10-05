# Legacy Pester fixture: It names without a colon. 2.x uses the whole name as the ID and
# warns; 3.0 takes the ID as written (design section 3.1 and 8).
Describe "Contoso naming" -Tag "Contoso" {
    It "CT0001 Guest invitations are restricted to admins" -Tag "CT0001" {
        $setting = 'adminsAndGuestInviters'
        $setting | Should -BeIn @('adminsAndGuestInviters', 'none')
    }

    It "Ensure the break glass account exists" {
        $accounts = @('bg1@contoso.example')
        $accounts.Count | Should -BeGreaterOrEqual 1
    }
}
