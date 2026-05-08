BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Get-MtSession — GitHubAuthHeader redaction' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubAuthHeader = $null
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubAuthHeader = $null
        }
    }

    Context 'When GitHubAuthHeader is null' {
        It 'Returns null without error' {
            $result = Get-MtSession
            $result.GitHubAuthHeader | Should -BeNullOrEmpty
        }
    }

    Context 'When GitHubAuthHeader is a hashtable with Authorization (PascalCase)' {
        It 'Redacts Authorization and preserves other headers' {
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader = @{
                    Authorization          = 'Bearer ghp_realtoken123'
                    Accept                 = 'application/vnd.github+json'
                    'X-GitHub-Api-Version' = '2022-11-28'
                    'User-Agent'           = 'Maester-GitHubCis'
                }
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader | Should -BeOfType [System.Collections.IDictionary]
            $result.GitHubAuthHeader['Authorization']          | Should -Be '<redacted>'
            $result.GitHubAuthHeader['Accept']                 | Should -Be 'application/vnd.github+json'
            $result.GitHubAuthHeader['X-GitHub-Api-Version']   | Should -Be '2022-11-28'
            $result.GitHubAuthHeader['User-Agent']             | Should -Be 'Maester-GitHubCis'
        }
    }

    Context 'When GitHubAuthHeader has lowercase authorization key' {
        It 'Redacts the lowercase key and leaves no token in any value' {
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader = @{
                    authorization = 'Bearer ghp_realtoken123'
                    Accept        = 'application/vnd.github+json'
                }
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader['authorization'] | Should -Be '<redacted>'
            foreach ($v in $result.GitHubAuthHeader.Values) {
                $v | Should -Not -Be 'Bearer ghp_realtoken123'
            }
        }
    }

    Context 'When GitHubAuthHeader has uppercase AUTHORIZATION key' {
        It 'Redacts the uppercase key' {
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader = @{
                    AUTHORIZATION = 'Bearer ghp_realtoken123'
                    Accept        = 'application/vnd.github+json'
                }
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader['AUTHORIZATION'] | Should -Be '<redacted>'
            foreach ($v in $result.GitHubAuthHeader.Values) {
                $v | Should -Not -Be 'Bearer ghp_realtoken123'
            }
        }
    }

    Context 'When GitHubAuthHeader has BOTH Authorization and authorization' {
        It 'Redacts every Authorization-like key' {
            InModuleScope Maester {
                $h = [ordered]@{}
                $h['Authorization'] = 'Bearer ghp_realtoken123'
                $h['authorization'] = 'Bearer ghp_realtoken123'
                $h['Accept']        = 'application/vnd.github+json'
                $__MtSession.GitHubAuthHeader = $h
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader['Authorization'] | Should -Be '<redacted>'
            $result.GitHubAuthHeader['authorization'] | Should -Be '<redacted>'
            foreach ($v in $result.GitHubAuthHeader.Values) {
                $v | Should -Not -Be 'Bearer ghp_realtoken123'
            }
        }
    }

    Context 'When GitHubAuthHeader is an OrderedDictionary' {
        It 'Redacts Authorization and preserves remaining keys' {
            InModuleScope Maester {
                $h = [ordered]@{}
                $h['Authorization']        = 'Bearer ghp_realtoken123'
                $h['Accept']               = 'application/vnd.github+json'
                $h['X-GitHub-Api-Version'] = '2022-11-28'
                $__MtSession.GitHubAuthHeader = $h
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader | Should -BeOfType [System.Collections.IDictionary]
            $result.GitHubAuthHeader['Authorization']        | Should -Be '<redacted>'
            $result.GitHubAuthHeader['Accept']               | Should -Be 'application/vnd.github+json'
            $result.GitHubAuthHeader['X-GitHub-Api-Version'] | Should -Be '2022-11-28'
        }
    }

    Context 'When GitHubAuthHeader is an unsupported non-null shape' {
        It 'Replaces the entire value with the redacted sentinel string (fail-closed)' {
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader = 'Bearer ghp_realtoken123'
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader | Should -Be '<redacted>'
        }

        It 'Replaces a PSCustomObject auth-like blob with the redacted sentinel string' {
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader = [PSCustomObject]@{ Authorization = 'Bearer ghp_realtoken123' }
            }
            $result = Get-MtSession
            $result.GitHubAuthHeader | Should -Be '<redacted>'
        }
    }

    Context 'Live session is not mutated by Get-MtSession' {
        It 'Leaves $__MtSession.GitHubAuthHeader.Authorization intact for internal callers' {
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader = @{
                    Authorization = 'Bearer ghp_realtoken123'
                    Accept        = 'application/vnd.github+json'
                }
            }
            Get-MtSession | Out-Null
            InModuleScope Maester {
                $__MtSession.GitHubAuthHeader['Authorization'] | Should -Be 'Bearer ghp_realtoken123'
            }
        }
    }
}
