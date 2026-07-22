BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtContext — Microsoft Graph scopes' {
    It 'Uses the shared comparison when a ReadWrite scope satisfies a Read scope' {
        Mock Get-MgContext {
            [PSCustomObject]@{
                AuthType = 'Delegated'
                Scopes   = @('User.ReadWrite')
            }
        } -ModuleName Maester

        Mock Get-MtGraphScope {
            @('User.Read')
        } -ModuleName Maester

        InModuleScope Maester {
            Test-MtContext | Should -BeTrue
        }
    }

    It 'Reports scopes that remain missing after comparison' {
        Mock Get-MgContext {
            [PSCustomObject]@{
                AuthType = 'Delegated'
                Scopes   = @('Directory.Read.All')
            }
        } -ModuleName Maester

        Mock Get-MtGraphScope {
            @(
                'Directory.Read.All'
                'Reports.Read.All'
            )
        } -ModuleName Maester

        InModuleScope Maester {
            { Test-MtContext } |
                Should -Throw -ExpectedMessage '*Reports.Read.All*'
        }
    }
}
