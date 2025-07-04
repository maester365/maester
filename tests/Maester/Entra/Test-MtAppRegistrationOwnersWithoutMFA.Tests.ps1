Describe "Maester/Entra" -Tag "MT.1063", "Entra", "Security", "Applications" {
    It "MT.1063: All Application Owners should have MFA registered" {
        $result = Test-MtAppRegistrationOwnerWithoutMFA
        $result | Should -Be $true -Because "All application owners should have MFA registered."
    }
}