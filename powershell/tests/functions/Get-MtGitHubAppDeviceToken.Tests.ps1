BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Get-MtGitHubAppDeviceToken' {
    It 'Completes GitHub App device flow and returns an access token' {
        $script:pollCount = 0

        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/device/code' } {
            [PSCustomObject]@{
                Content = '{"device_code":"device-code","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":1}'
            }
        }
        Mock Open-MtBrowserUrl -ModuleName Maester { $true }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/oauth/access_token' } {
            $script:pollCount++
            if ($script:pollCount -eq 1) {
                [PSCustomObject]@{ Content = '{"error":"authorization_pending"}' }
            } else {
                [PSCustomObject]@{ Content = '{"access_token":"ghu_test","expires_in":28800,"token_type":"bearer","scope":""}' }
            }
        }

        InModuleScope Maester {
            $result = Get-MtGitHubAppDeviceToken -ClientId 'Iv23liV3mw0hSq0gn957' 6>$null

            $result.AccessToken | Should -Be 'ghu_test'
            $result.FailureReason | Should -BeNullOrEmpty
            $result.ExpiresAt | Should -Not -BeNullOrEmpty
        }

        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 1 -ParameterFilter {
            $Uri -eq 'https://github.com/login/device/code' -and $Body.client_id -eq 'Iv23liV3mw0hSq0gn957'
        }
        Should -Invoke Open-MtBrowserUrl -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
            $Uri -eq 'https://github.com/login/device'
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -ParameterFilter {
            $Uri -eq 'https://github.com/login/oauth/access_token' -and
            $Body.client_id -eq 'Iv23liV3mw0hSq0gn957' -and
            $Body.device_code -eq 'device-code' -and
            $Body.grant_type -eq 'urn:ietf:params:oauth:grant-type:device_code'
        }
    }

    It 'Returns GitHubDeviceFlowDenied when the user denies authorization' {
        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/device/code' } {
            [PSCustomObject]@{
                Content = '{"device_code":"device-code","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":1}'
            }
        }
        Mock Open-MtBrowserUrl -ModuleName Maester { $true }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/oauth/access_token' } {
            [PSCustomObject]@{ Content = '{"error":"access_denied"}' }
        }

        InModuleScope Maester {
            $result = Get-MtGitHubAppDeviceToken -ClientId 'Iv23liV3mw0hSq0gn957' 6>$null

            $result.AccessToken | Should -BeNullOrEmpty
            $result.FailureReason | Should -Be 'GitHubDeviceFlowDenied'
        }
    }

    It 'Displays the device code without trailing punctuation when the browser opens' {
        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/device/code' } {
            [PSCustomObject]@{
                Content = '{"device_code":"device-code","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":1}'
            }
        }
        Mock Open-MtBrowserUrl -ModuleName Maester { $true }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/oauth/access_token' } {
            [PSCustomObject]@{ Content = '{"error":"access_denied"}' }
        }

        $output = InModuleScope Maester {
            Get-MtGitHubAppDeviceToken -ClientId 'Iv23liV3mw0hSq0gn957' 6>&1 | Out-String
        }

        $output | Should -Match 'Opened https://github\.com/login/device in your browser\. Enter code ABCD-1234'
        $output | Should -Not -Match 'ABCD-1234\.'
    }

    It 'Displays the device code without trailing punctuation when the browser does not open' {
        Mock Start-Sleep -ModuleName Maester {}
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/device/code' } {
            [PSCustomObject]@{
                Content = '{"device_code":"device-code","user_code":"ABCD-1234","verification_uri":"https://github.com/login/device","expires_in":900,"interval":1}'
            }
        }
        Mock Open-MtBrowserUrl -ModuleName Maester { $false }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://github.com/login/oauth/access_token' } {
            [PSCustomObject]@{ Content = '{"error":"access_denied"}' }
        }

        $output = InModuleScope Maester {
            Get-MtGitHubAppDeviceToken -ClientId 'Iv23liV3mw0hSq0gn957' 6>&1 | Out-String
        }

        $output | Should -Match 'Open https://github\.com/login/device and enter code ABCD-1234'
        $output | Should -Not -Match 'ABCD-1234\.'
    }
}
