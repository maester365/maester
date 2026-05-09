BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Invoke-MtGitHubRequest' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [PSCustomObject]@{
                Connected    = $true
                Organization = 'myorg'
                ApiBaseUri   = 'https://api.github.com'
                ApiVersion   = '2022-11-28'
            }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer faketoken' }
            $__MtSession.GitHubCache      = @{}
        }
    }

    AfterEach {
        InModuleScope Maester {
            $__MtSession.GitHubConnection = $null
            $__MtSession.GitHubAuthHeader = $null
            $__MtSession.GitHubCache      = @{}
        }
    }

    Context 'Connection guard' {
        It 'Throws when GitHubConnection is null' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = $null
                { Invoke-MtGitHubRequest '/orgs/myorg' } | Should -Throw '*Connect-MtGitHub*'
            }
        }

        It 'Throws when Connected = $false' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection = [PSCustomObject]@{ Connected = $false }
                { Invoke-MtGitHubRequest '/orgs/myorg' } | Should -Throw '*Connect-MtGitHub*'
            }
        }
    }

    Context 'Cache behavior' {
        BeforeEach {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{ Content = '{"login":"myorg"}'; Headers = @{} }
            }
        }

        It 'Returns cached result; Invoke-WebRequest called only once for two identical calls' {
            InModuleScope Maester {
                Invoke-MtGitHubRequest '/orgs/myorg' | Out-Null
                Invoke-MtGitHubRequest '/orgs/myorg' | Out-Null
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        }

        It 'Cache key is ApiVersion|absoluteUri' {
            InModuleScope Maester {
                Invoke-MtGitHubRequest '/orgs/myorg' | Out-Null
                $expectedKey = '2022-11-28|https://api.github.com/orgs/myorg'
                $__MtSession.GitHubCache.ContainsKey($expectedKey) | Should -BeTrue
            }
        }

        It 'Stores result in cache on successful call (no -DisableCache)' {
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg'
                $result.login | Should -Be 'myorg'
                $__MtSession.GitHubCache.Count | Should -Be 1
                $cacheKey = '2022-11-28|https://api.github.com/orgs/myorg'
                $__MtSession.GitHubCache[$cacheKey].login | Should -Be 'myorg'
            }
        }

        It '-DisableCache bypasses existing cache entry and does NOT store result' {
            InModuleScope Maester {
                $cacheKey = '2022-11-28|https://api.github.com/orgs/myorg'
                $__MtSession.GitHubCache[$cacheKey] = [PSCustomObject]@{ login = 'cached-value' }

                $result = Invoke-MtGitHubRequest '/orgs/myorg' -DisableCache

                # Web request was made (bypassed cache)
                $result.login | Should -Be 'myorg'
                # Original cache entry is untouched (not overwritten)
                $__MtSession.GitHubCache[$cacheKey].login | Should -Be 'cached-value'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        }
    }

    Context 'Non-paginated request' {
        It 'Returns single object body without -Paginate' {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{ Content = '{"login":"myorg","plan":{"name":"enterprise"}}'; Headers = @{} }
            }
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg'
                $result.login | Should -Be 'myorg'
            }
        }
    }

    Context 'Pagination' {
        It 'Follows Link rel=next until no next link; returns all items combined' {
            # [?&]page= matches ?page= or &page= but NOT per_page= (per_page contains 'page=' at offset 4)
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -notmatch '[?&]page=\d' } {
                [PSCustomObject]@{
                    Content = '[{"id":1},{"id":2}]'
                    Headers = @{ 'Link' = '<https://api.github.com/orgs/myorg/members?page=2>; rel="next"' }
                }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '[?&]page=\d' } {
                [PSCustomObject]@{ Content = '[{"id":3}]'; Headers = @{} }
            }

            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg/members' -Paginate
                $result.Count | Should -Be 3
                $result[2].id | Should -Be 3
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
        }
    }

    Context 'Pagination cross-origin guard' {
        It 'Throws and stops paginating when next link is on a different origin' {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{
                    Content = '[{"id":1}]'
                    Headers = @{ 'Link' = '<https://evil.example/orgs/myorg/members?page=2>; rel="next"' }
                }
            }
            InModuleScope Maester {
                { Invoke-MtGitHubRequest '/orgs/myorg/members' -Paginate } |
                    Should -Throw '*outside the configured ApiBaseUri*'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        }

        It 'Allows a same-origin next link with a base path prefix (GHE-style /api/v3)' {
            InModuleScope Maester {
                $__MtSession.GitHubConnection.ApiBaseUri = 'https://ghe.example.com/api/v3'
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -notmatch '[?&]page=\d' } {
                [PSCustomObject]@{
                    Content = '[{"id":1}]'
                    Headers = @{ 'Link' = '<https://ghe.example.com/api/v3/orgs/myorg/members?page=2>; rel="next"' }
                }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '[?&]page=\d' } {
                [PSCustomObject]@{ Content = '[{"id":2}]'; Headers = @{} }
            }
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg/members' -Paginate
                $result.Count | Should -Be 2
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
        }
    }

    Context 'Rate limit handling' {
        It 'Emits verbose message when x-ratelimit-remaining is 0 on successful response' {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{
                    Content = '{"login":"myorg"}'
                    Headers = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' }
                }
            }
            InModuleScope Maester {
                $allOutput   = Invoke-MtGitHubRequest '/orgs/myorg' -Verbose 4>&1
                $verboseMsgs = ($allOutput | Where-Object { $_ -is [System.Management.Automation.VerboseRecord] }).Message
                $verboseMsgs | Should -Match 'rate limit'
            }
        }

        It 'Throws on primary rate-limit exhaustion (HTTP 403, remaining = 0)' {
            Mock Invoke-WebRequest -ModuleName Maester {
                $fakeResp = [PSCustomObject]@{
                    StatusCode = 403
                    Headers    = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '9999999999' }
                }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
                throw $ex
            }
            InModuleScope Maester {
                { Invoke-MtGitHubRequest '/orgs/myorg' } | Should -Throw '*rate limit*'
            }
        }

        It 'Rethrows ordinary 403 without rate-limit headers as the original error (not a rate-limit message)' {
            Mock Invoke-WebRequest -ModuleName Maester {
                $fakeResp = [PSCustomObject]@{
                    StatusCode = 403
                    Headers    = @{}
                }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
                throw $ex
            }
            InModuleScope Maester {
                $thrownMessage = $null
                try { Invoke-MtGitHubRequest '/orgs/myorg' } catch { $thrownMessage = $_.Exception.Message }
                $thrownMessage | Should -Match 'Forbidden'
                $thrownMessage | Should -Not -Match 'rate limit'
            }
        }

        It 'Rethrows original error when x-ratelimit-remaining is malformed (no parse exception)' {
            Mock Invoke-WebRequest -ModuleName Maester {
                $fakeResp = [PSCustomObject]@{
                    StatusCode = 403
                    Headers    = @{ 'x-ratelimit-remaining' = 'not-a-number' }
                }
                $ex = [System.Exception]::new('Forbidden')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
                throw $ex
            }
            InModuleScope Maester {
                $thrownMessage = $null
                try { Invoke-MtGitHubRequest '/orgs/myorg' } catch { $thrownMessage = $_.Exception.Message }
                $thrownMessage | Should -Match 'Forbidden'
                $thrownMessage | Should -Not -Match 'rate limit'
                $thrownMessage | Should -Not -Match 'Cannot convert'
            }
        }

        It 'Throws on secondary rate-limit (HTTP 429, retry-after header present)' {
            Mock Invoke-WebRequest -ModuleName Maester {
                $fakeResp = [PSCustomObject]@{
                    StatusCode = 429
                    Headers    = @{ 'retry-after' = '30' }
                }
                $ex = [System.Exception]::new('Too Many Requests')
                Add-Member -InputObject $ex -MemberType NoteProperty -Name Response -Value $fakeResp
                throw $ex
            }
            InModuleScope Maester {
                { Invoke-MtGitHubRequest '/orgs/myorg' } | Should -Throw '*secondary rate limit*'
            }
        }
    }
}
