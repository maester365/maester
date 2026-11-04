BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
}

Describe 'Test-MtGraphNotFoundError' -Tag 'Unit' {
    It 'returns <Expected> for a <Form> status code of <StatusCode>' -ForEach @(
        @{ Form = 'string'; StatusCode = 'NotFound'; Expected = $true }
        @{ Form = 'string'; StatusCode = 'Forbidden'; Expected = $false }
        @{ Form = 'integer'; StatusCode = 404; Expected = $true }
        @{ Form = 'integer'; StatusCode = 429; Expected = $false }
        @{ Form = 'enum'; StatusCode = [System.Net.HttpStatusCode]::NotFound; Expected = $true }
        @{ Form = 'enum'; StatusCode = [System.Net.HttpStatusCode]::Forbidden; Expected = $false }
    ) {
        $exception = [System.Exception]::new('Graph request failed.')
        $exception | Add-Member -NotePropertyName StatusCode -NotePropertyValue $StatusCode
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'NotSpecified', $null)

        InModuleScope Maester -Parameters @{ ErrorRecord = $errorRecord } {
            Test-MtGraphNotFoundError -ErrorRecord $ErrorRecord
        } | Should -Be $Expected
    }

    It 'does not read a 404 inside an id as not found' {
        $exception = [System.Exception]::new('Forbidden. Request id 7c404e1a-0000-0000-0000-000000000000.')
        $errorRecord = [System.Management.Automation.ErrorRecord]::new($exception, 'GraphError', 'NotSpecified', $null)

        InModuleScope Maester -Parameters @{ ErrorRecord = $errorRecord } {
            Test-MtGraphNotFoundError -ErrorRecord $ErrorRecord
        } | Should -BeFalse
    }
}
