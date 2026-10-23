BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Update-MtMaesterApp' -Tag 'Unit' {
    BeforeEach {
        # Stops the command right after parameter binding, before it talks to Azure.
        Mock -ModuleName Maester Test-MtAzContext { $false }
    }

    It 'binds the <Switch> switch' -ForEach @(
        @{ Switch = 'SendMail' }
        @{ Switch = 'SendTeamsMessage' }
        @{ Switch = 'Privileged' }
    ) {
        $arguments = @{ AppId = '00000000-0000-0000-0000-000000000001'; $Switch = $true }

        { Update-MtMaesterApp @arguments } | Should -Not -Throw
    }

    It 'binds all three switches together by object id' {
        { Update-MtMaesterApp -Id '00000000-0000-0000-0000-000000000001' -SendMail -SendTeamsMessage -Privileged } |
            Should -Not -Throw
    }
}
