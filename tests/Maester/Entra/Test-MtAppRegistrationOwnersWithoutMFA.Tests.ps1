Describe 'Maester/Entra' -Tag 'App', 'Entra', 'Full', 'LongRunning', 'Security' {
    It 'MT.1063: All App registration owners should have MFA registered' -Tag 'MT.1063' {
        $result = Test-MtAppRegistrationOwnersWithoutMFA
        $result | Should -Be $true -Because 'All App registration owners should have MFA registered.'
    }
}
