BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Compare-MtGraphScope' {
    It 'Normalizes included and required scopes before comparison' {
        $Result = InModuleScope Maester {
            Compare-MtGraphScope `
                -CurrentScopes @(
                    'Reports.Read.All'
                    'Directory.Read.All'
                    'Reports.Read.All'
                    ''
                ) `
                -RequiredScopes @(
                    'Directory.Read.All'
                    'Policy.Read.All'
                    'Policy.Read.All'
                    $null
                )
        }

        $Result.IncludedScopes | Should -Be @(
            'Directory.Read.All'
            'Reports.Read.All'
        )
        $Result.RequiredScopes | Should -Be @(
            'Directory.Read.All'
            'Policy.Read.All'
        )
        $Result.MissingScopes | Should -Be @('Policy.Read.All')
    }

    It 'Treats matching ReadWrite scopes as satisfying Read scopes' {
        $Result = InModuleScope Maester {
            Compare-MtGraphScope `
                -CurrentScopes @(
                    'Policy.ReadWrite.ConditionalAccess'
                    'User.ReadWrite'
                ) `
                -RequiredScopes @(
                    'Policy.Read.ConditionalAccess'
                    'User.Read'
                )
        }

        $Result.MissingScopes | Should -BeNullOrEmpty
    }

    It 'Does not treat unrelated scope names as ReadWrite equivalents' {
        $Result = InModuleScope Maester {
            Compare-MtGraphScope `
                -CurrentScopes @('User.ReadWriteBasic.All') `
                -RequiredScopes @('User.ReadBasic.All')
        }

        $Result.MissingScopes | Should -Be @('User.ReadBasic.All')
    }
}
