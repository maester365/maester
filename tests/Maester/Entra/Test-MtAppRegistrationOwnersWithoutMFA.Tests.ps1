Describe "Maester/Entra" -Tag "MT.1063", "Entra", "Security", "Applications", "Full" {
    It "MT.1063: All App registration owners should have MFA registered" {
        $result = Test-MtAppRegistrationOwnersWithoutMFA
        $result | Should -Be $true -Because "All App registration owners should have MFA registered."
    }
}