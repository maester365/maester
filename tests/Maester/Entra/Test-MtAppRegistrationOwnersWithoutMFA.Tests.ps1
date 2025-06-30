BeforeAll {
    . $PSScriptRoot/Test-MtAppRegistrationOwnersWithoutMFA.ps1
}

Describe "Maester/Entra" -Tag "MT.1063", "Entra", "Security", "Applications" {
    It "MT.1063: All Application Owners should have MFA set up" {
        $result = Test-MtAppRegistrationOwnerWithoutMFA
        $result | Should -Be $true -Because "All App Registration owners should have MFA set up."
    }
}