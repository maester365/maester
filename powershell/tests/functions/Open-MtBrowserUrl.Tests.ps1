BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Open-MtBrowserUrl' {
    Context 'URL validation' {
        It 'Returns false for whitespace input' {
            InModuleScope Maester {
                Open-MtBrowserUrl -Uri '   ' | Should -BeFalse
            }
        }

        It 'Rejects non-HTTP(S) and non-absolute URLs before launching' -TestCases @(
            @{ Uri = 'file:///tmp/maester-open-browser-url-test' }
            @{ Uri = '/tmp/maester-open-browser-url-test' }
            @{ Uri = 'C:\Windows\notepad.exe' }
            @{ Uri = './relative/path' }
            @{ Uri = 'mailto:test@example.com' }
            @{ Uri = 'javascript:alert(1)' }
        ) {
            param($Uri)

            InModuleScope Maester -Parameters @{ TestUri = $Uri } {
                Open-MtBrowserUrl -Uri $TestUri | Should -BeFalse
            }
        }
    }
}
