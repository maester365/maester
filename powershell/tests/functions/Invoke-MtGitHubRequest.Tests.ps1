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

    Context 'Request timeouts' {
        It 'Bounds every page for legacy and metadata requests (<Metadata>)' -ForEach @(@{ Metadata = $false }, @{ Metadata = $true }) {
            Mock Invoke-WebRequest -ModuleName Maester {
                $headers = if ($Uri -like '*page=2') { @{} } else { @{ Link = '<https://api.github.com/orgs/myorg/repos?page=2>; rel="next"' } }
                [pscustomobject]@{ Content = '[{"id":1}]'; Headers = $headers }
            }
            InModuleScope Maester -Parameters @{ Metadata = $Metadata } {
                Invoke-MtGitHubRequest '/orgs/myorg/repos' -Paginate -IncludeMetadata:$Metadata | Out-Null
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly -ParameterFilter {
                $ConnectionTimeoutSeconds -eq 30 -and $OperationTimeoutSeconds -eq 30
            }
        }

        It 'Retains earlier pages on timeout without caching incomplete retrievals' {
            Mock Invoke-WebRequest -ModuleName Maester {
                if ($Uri -like '*page=2') { throw [System.TimeoutException]::new('Synthetic stalled request.') }
                [pscustomobject]@{ Content = '[{"id":1}]'; Headers = @{ Link = '<https://api.github.com/orgs/myorg/repos?page=2>; rel="next"' } }
            }
            InModuleScope Maester {
                $caught = $null
                try { Invoke-MtGitHubRequest '/orgs/myorg/repos' -Paginate -IncludeMetadata | Out-Null } catch { $caught = $_ }
                $caught.Exception | Should -BeOfType ([System.TimeoutException])
                $caught.Exception.Data['GitHubPartialResponse'].Data.id | Should -Be 1
                $__MtSession.GitHubCache.Count | Should -Be 0
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Times 2 -Exactly
        }
    }

    Context 'Cache key helper' {
        It 'Builds cache keys as ApiVersion|absoluteUri' {
            InModuleScope Maester {
                Get-MtGitHubCacheKey -ApiVersion '2022-11-28' -AbsoluteUri 'https://api.github.com/orgs/myorg' | Should -Be '2022-11-28|https://api.github.com/orgs/myorg'
            }
        }
    }

    Context 'Cache behavior' {
        BeforeEach {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{ Content = '{"login":"myorg"}'; Headers = @{} }
            }
            Mock Get-MtGitHubCacheKey -ModuleName Maester {
                "$ApiVersion|$AbsoluteUri"
            }
        }

        It 'Returns cached result; Invoke-WebRequest called only once for two identical calls' {
            InModuleScope Maester {
                Invoke-MtGitHubRequest '/orgs/myorg' | Out-Null
                Invoke-MtGitHubRequest '/orgs/myorg' | Out-Null
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
            Should -Invoke Get-MtGitHubCacheKey -ModuleName Maester -Exactly -Times 2 -ParameterFilter {
                $ApiVersion -eq '2022-11-28' -and $AbsoluteUri -eq 'https://api.github.com/orgs/myorg'
            }
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

    Context 'Pagination of empty arrays' {
        It 'Returns an empty result (count 0) when the only page is `[]` with no next link' {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{ Content = '[]'; Headers = @{} }
            }
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg/members' -Paginate
                @($result).Count | Should -Be 0
                # Must not contain a spurious $null item (the regression case).
                @($result) -contains $null | Should -BeFalse
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        }

        It 'Skips an empty intermediate page without contributing $null items' {
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -notmatch '[?&]page=\d' } {
                [PSCustomObject]@{
                    Content = '[]'
                    Headers = @{ 'Link' = '<https://api.github.com/orgs/myorg/members?page=2>; rel="next"' }
                }
            }
            Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '[?&]page=\d' } {
                [PSCustomObject]@{ Content = '[{"id":7}]'; Headers = @{} }
            }
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg/members' -Paginate
                @($result).Count | Should -Be 1
                @($result)[0].id | Should -Be 7
                @($result) -contains $null | Should -BeFalse
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
        }

        It 'Non-paginated `[]` response does not return a single $null item' {
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{ Content = '[]'; Headers = @{} }
            }
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg/members'
                @($result).Count | Should -Be 0
                @($result) -contains $null | Should -BeFalse
            }
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

        It 'Does not throw on successful response when x-ratelimit-reset is out of range for FromUnixTimeSeconds' {
            # 253402300800 is one second past the documented upper bound of FromUnixTimeSeconds
            # (max accepted = 253402300799 = 9999-12-31T23:59:59Z). A bogus reset epoch from
            # an upstream proxy must not raise ArgumentOutOfRangeException and mask the response.
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{
                    Content = '{"login":"myorg"}'
                    Headers = @{ 'x-ratelimit-remaining' = '0'; 'x-ratelimit-reset' = '253402300800' }
                }
            }
            InModuleScope Maester {
                $result = Invoke-MtGitHubRequest '/orgs/myorg'
                $result.login | Should -Be 'myorg'
                # The valid response survives a malformed reset. A subsequent network request is
                # blocked until a new connection because the primary reset deadline is unknown.
                { Invoke-MtGitHubRequest '/orgs/myorg' -DisableCache } | Should -Throw '*rate limit*'
            }
            Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
        }

        It 'Does not throw on successful response when x-ratelimit-remaining is malformed' {
            # Successful response body is valid; a malformed rate-limit header (e.g. an upstream
            # proxy rewriting the value) must not raise a parse exception that masks the response.
            Mock Invoke-WebRequest -ModuleName Maester {
                [PSCustomObject]@{
                    Content = '{"login":"myorg"}'
                    Headers = @{ 'x-ratelimit-remaining' = 'not-a-number'; 'x-ratelimit-reset' = 'also-bogus' }
                }
            }
            InModuleScope Maester {
                { Invoke-MtGitHubRequest '/orgs/myorg' } | Should -Not -Throw
                $result = Invoke-MtGitHubRequest '/orgs/myorg' -DisableCache
                $result.login | Should -Be 'myorg'
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


Describe 'Opt-in GitHub REST evidence metadata' {
    BeforeEach {
        $script:metadataBody = '{"value":true}'
        $script:metadataHeaders = @{}
        InModuleScope Maester {
            $__MtSession.GitHubConnection = [pscustomobject]@{ Connected = $true; Organization = 'fixture-org'; ApiBaseUri = 'https://api.github.com'; ApiVersion = '2022-11-28' }
            $__MtSession.GitHubAuthHeader = @{ Authorization = 'Bearer synthetic'; 'X-GitHub-Api-Version' = '2022-11-28' }
            $__MtSession.GitHubCache = @{}
        }
        Mock Invoke-WebRequest -ModuleName Maester { [pscustomobject]@{ Content = $script:metadataBody; Headers = $script:metadataHeaders } }
    }
    AfterEach {
        InModuleScope Maester { $__MtSession.GitHubConnection = $null; $__MtSession.GitHubAuthHeader = $null; $__MtSession.GitHubCache = @{} }
    }
    It 'Separates documented empty arrays from defensive unusable <Body>' -ForEach @(
        @{ Body = '[]'; Valid = $true; Count = 0 }
        @{ Body = '[ ]'; Valid = $true; Count = 0 }
        @{ Body = '[{"name":"main"}]'; Valid = $true; Count = 1 }
        @{ Body = '[null]'; Valid = $false; Count = 1 }
        @{ Body = '[null,{"name":"main"}]'; Valid = $false; Count = 2 }
        @{ Body = '[[{"name":"main"}]]'; Valid = $false; Count = 1 }
        @{ Body = '[1]'; Valid = $false; Count = 1 }
        @{ Body = 'null'; Valid = $false; Count = 0 }
        @{ Body = ''; Valid = $false; Count = 0 }
        @{ Body = '{}'; Valid = $false; Count = 0 }
    ) {
        $script:metadataBody = $Body
        $out = InModuleScope Maester { Invoke-MtGitHubRequest '/repos/fixture-org/repo/branches' -Paginate -IncludeMetadata -ApiVersion '2026-03-10' }
        $out.CollectionIntegrityValid | Should -Be $Valid
        $out.Data.Count | Should -Be $Count
        $out.PaginationComplete | Should -BeTrue
        if (-not $Valid) { InModuleScope Maester { $__MtSession.GitHubCache.Count } | Should -Be 0 }
    }
    It 'Does not upgrade an existing legacy cached body into evidence metadata' {
        $out = InModuleScope Maester {
            Invoke-MtGitHubRequest '/orgs/fixture-org' | Out-Null
            $metadata = Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata
            $legacy = Invoke-MtGitHubRequest '/orgs/fixture-org'
            [pscustomobject]@{ Metadata = $metadata; Legacy = $legacy }
        }
        $out.Metadata.StartedUtc | Should -BeOfType DateTimeOffset
        $out.Legacy.PSObject.Properties.Name | Should -Not -Contain 'StartedUtc'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Isolates version override and leaves the session header unchanged' {
        InModuleScope Maester {
            Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata -ApiVersion '2026-03-10' | Out-Null
            Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata | Out-Null
            $__MtSession.GitHubAuthHeader['X-GitHub-Api-Version'] | Should -Be '2022-11-28'
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1 -ParameterFilter { $Headers['X-GitHub-Api-Version'] -eq '2026-03-10' }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Separates explicit single-page and paginated modes with the same URL' {
        $script:metadataBody = '[{"name":"main"}]'
        $out = InModuleScope Maester {
            $single = Invoke-MtGitHubRequest '/branches?per_page=100' -IncludeMetadata
            $all = Invoke-MtGitHubRequest '/branches?per_page=100' -IncludeMetadata -Paginate
            Invoke-MtGitHubRequest '/branches?per_page=100' -IncludeMetadata -Paginate | Out-Null
            @($single, $all)
        }
        $out[0].PaginationComplete | Should -BeFalse
        $out[1].PaginationComplete | Should -BeTrue
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Keeps one metadata snapshot throughout a run' {
        InModuleScope Maester {
            $first = Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata
            $next = Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata
            $next.StartedUtc | Should -Be $first.StartedUtc
            $next.CompletedUtc | Should -Be $first.CompletedUtc
            $next.CompletedUtc = [DateTimeOffset]::UtcNow.AddMinutes(-6)
            $fresh = Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata
            $fresh.CompletedUtc | Should -Be $next.CompletedUtc
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }
    It 'Does not cache partial SSO evidence' {
        $script:metadataBody = '[]'
        $script:metadataHeaders = @{ 'X-GitHub-SSO' = 'partial-results; organizations=1' }
        $out = InModuleScope Maester { Invoke-MtGitHubRequest '/branches' -IncludeMetadata -Paginate }
        $out.AccessLimited | Should -BeTrue
        $out.CollectionIntegrityValid | Should -BeFalse
        InModuleScope Maester { $__MtSession.GitHubCache.Count } | Should -Be 0
    }
    It 'Follows a valid empty intermediate page and retains invalid members from later pages' {
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -notmatch '[?&]page=2' } {
            [pscustomobject]@{ Content = '[]'; Headers = @{ Link = '<https://api.github.com/branches?page=2>; rel="next"' } }
        }
        Mock Invoke-WebRequest -ModuleName Maester -ParameterFilter { $Uri -match '[?&]page=2' } { [pscustomobject]@{ Content = '[null,{"name":"main"}]'; Headers = @{} } }
        $out = InModuleScope Maester { Invoke-MtGitHubRequest '/branches' -IncludeMetadata -Paginate }
        $out.PageCount | Should -Be 2
        $out.Data.Count | Should -Be 2
        $out.CollectionIntegrityValid | Should -BeFalse
    }
    It 'Rejects foreign pagination links without forwarding credentials' {
        $script:metadataBody = '[]'
        $script:metadataHeaders = @{ Link = '<https://untrusted.invalid/branches?page=2>; rel="next"' }
        { InModuleScope Maester { Invoke-MtGitHubRequest '/branches' -IncludeMetadata -Paginate } } | Should -Throw '*foreign*'
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 1
    }
    It 'Rejects a pagination cycle and never caches the incomplete traversal' {
        $script:metadataBody = '[]'
        $script:metadataHeaders = @{ Link = '<https://api.github.com/branches?per_page=100>; rel="next"' }
        { InModuleScope Maester { Invoke-MtGitHubRequest '/branches' -IncludeMetadata -Paginate } } | Should -Throw '*cycle*'
        InModuleScope Maester { $__MtSession.GitHubCache.Count } | Should -Be 0
    }
    It 'Preserves DisableCache read/write bypass for metadata' {
        InModuleScope Maester {
            Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata -DisableCache | Out-Null
            Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata -DisableCache | Out-Null
            $__MtSession.GitHubCache.Count | Should -Be 0
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }
    It 'Inspects single-page array items without claiming complete enumeration' {
        $script:metadataBody='[null,{"name":"main"}]'
        $out=InModuleScope Maester {Invoke-MtGitHubRequest '/branches' -IncludeMetadata}
        $out.Data.Count | Should -Be 2
        $out.CollectionIntegrityValid | Should -BeFalse
        $out.PaginationComplete | Should -BeFalse
        InModuleScope Maester {$__MtSession.GitHubCache.Count} | Should -Be 0
    }
    It 'Does not remove an expired metadata entry when DisableCache bypasses reads and writes' {
        InModuleScope Maester {
            $first=Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata
            $expired=[DateTimeOffset]::UtcNow.AddMinutes(-6)
            $first.CompletedUtc=$expired
            Invoke-MtGitHubRequest '/orgs/fixture-org' -IncludeMetadata -DisableCache | Out-Null
            $__MtSession.GitHubCache.Count | Should -Be 1
            $__MtSession.GitHubCache['Metadata|GET|2022-11-28|https://api.github.com/orgs/fixture-org|Paginate=False'].CompletedUtc | Should -Be $expired
        }
        Should -Invoke Invoke-WebRequest -ModuleName Maester -Exactly -Times 2
    }

}
