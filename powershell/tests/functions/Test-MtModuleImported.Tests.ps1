BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtModuleImported' {
    It 'Is true for an imported module and false for one that is not' {
        InModuleScope Maester {
            Test-MtModuleImported 'Maester' | Should -BeTrue
            Test-MtModuleImported 'NoSuchModule.ForMaesterTests' | Should -BeFalse
        }
    }
}
