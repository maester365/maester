BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Test-MtGitHubCiEnvironment' {
    BeforeEach {
        $script:saved = @{ CI = $env:CI; TF_BUILD = $env:TF_BUILD; GITHUB_ACTIONS = $env:GITHUB_ACTIONS }
        $env:CI = $null
        $env:TF_BUILD = $null
        $env:GITHUB_ACTIONS = $null
    }

    AfterEach {
        $env:CI = $script:saved.CI
        $env:TF_BUILD = $script:saved.TF_BUILD
        $env:GITHUB_ACTIONS = $script:saved.GITHUB_ACTIONS
    }

    It 'Is false when no CI variable is set' {
        InModuleScope Maester { Test-MtGitHubCiEnvironment } | Should -BeFalse
    }

    It 'Is true when <Name> is <Value>' -TestCases @(
        @{ Name = 'CI'; Value = 'true' }
        @{ Name = 'CI'; Value = '1' }
        @{ Name = 'TF_BUILD'; Value = 'True' }
        @{ Name = 'GITHUB_ACTIONS'; Value = 'true' }
    ) {
        Set-Item -Path "Env:$Name" -Value $Value
        InModuleScope Maester { Test-MtGitHubCiEnvironment } | Should -BeTrue
    }

    It 'Is false when <Name> is <Value>, so a developer who sets it to false can still sign in' -TestCases @(
        @{ Name = 'CI'; Value = 'false' }
        @{ Name = 'CI'; Value = 'False' }
        @{ Name = 'CI'; Value = '0' }
        @{ Name = 'CI'; Value = '' }
        @{ Name = 'TF_BUILD'; Value = 'False' }
        @{ Name = 'GITHUB_ACTIONS'; Value = 'false' }
    ) {
        Set-Item -Path "Env:$Name" -Value $Value
        InModuleScope Maester { Test-MtGitHubCiEnvironment } | Should -BeFalse
    }
}
