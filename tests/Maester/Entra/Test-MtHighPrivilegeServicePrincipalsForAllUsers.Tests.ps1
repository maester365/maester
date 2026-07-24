Describe 'Maester/Entra' -Tag 'Maester', 'Entra', 'App', 'Graph' {
    It 'MT.1186: Require explicit assignment of high-privilege first-party Entra Apps. See https://maester.dev/docs/tests/MT.1186' -Tag 'MT.1186' {
        Test-MtHighPrivilegeServicePrincipalsForAllUsers | Should -Be $true -Because 'high-privilege first-party service principals such as Azure PowerShell, Azure CLI, Microsoft Graph Command Line Tools, Graph Explorer, and Azure AD PowerShell should require explicit assignment to users'
    }
}
