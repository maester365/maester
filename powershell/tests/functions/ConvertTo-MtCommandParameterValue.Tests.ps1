BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name ConvertTo-MtCommandParameterValue

    class MtLeakyParameter {
        [string] $ConnectionString = 'Server=db;Password=hunter2'
        [string] ToString() { return "Config($($this.ConnectionString))" }
    }
}

Describe 'ConvertTo-MtCommandParameterValue' {
    It 'Quotes a string' {
        ConvertTo-MtCommandParameterValue -Value 'Entra' | Should -BeExactly "'Entra'"
    }

    It 'Writes a <Kind> as it is' -ForEach @(
        @{ Kind = 'number'; Value = 42; Expected = '42' }
        @{ Kind = 'boolean'; Value = $true; Expected = 'True' }
    ) {
        ConvertTo-MtCommandParameterValue -Value $Value | Should -BeExactly $Expected
    }

    It 'Renders an arbitrary object as its type name, never its ToString()' {
        # The recorded command is written to the result file and shown in the report. Interpolating
        # an object calls its own ToString(), so a caller-supplied type could place a secret there.
        $result = ConvertTo-MtCommandParameterValue -Value ([MtLeakyParameter]::new())

        $result | Should -BeExactly '<MtLeakyParameter>'
        $result | Should -Not -Match 'hunter2'
        $result | Should -Not -Match 'ConnectionString'
    }

    It 'Keeps the array form for a string array' {
        ConvertTo-MtCommandParameterValue -Value @('Entra', 'Teams') | Should -BeExactly "@('Entra', 'Teams')"
    }

    It 'Renders an object inside an array as its type name too' {
        $result = ConvertTo-MtCommandParameterValue -Value @('Entra', [MtLeakyParameter]::new())

        $result | Should -BeExactly "@('Entra', '<MtLeakyParameter>')"
        $result | Should -Not -Match 'hunter2'
    }

    It 'Returns an empty string for null' {
        ConvertTo-MtCommandParameterValue -Value $null | Should -BeExactly ''
    }

    It 'Renders a null element inside an array as an empty string' {
        ConvertTo-MtCommandParameterValue -Value @('Entra', $null) | Should -BeExactly "@('Entra', '')"
    }
}
