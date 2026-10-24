BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Invoke-MtGraphRequest' {
    BeforeEach {
        InModuleScope Maester {
            $__MtSession.GraphCache = @{}
            $__MtSession.GraphBaseUri = $null
        }
        # The environment the mocked Graph context reports. Tests reassign it to simulate a
        # context switch inside one PowerShell session.
        $script:MtTestEnvironment = 'Global'

        Mock Get-MgContext -ModuleName Maester { @{ Environment = $script:MtTestEnvironment } }
        Mock Get-MgEnvironment -ModuleName Maester {
            switch ($Name) {
                'China' { @{ GraphEndpoint = 'https://microsoftgraph.chinacloudapi.cn/' } }
                'USGov' { @{ GraphEndpoint = 'https://graph.microsoft.us/' } }
                # A custom environment whose endpoint carries a path of its own, as a reverse proxy
                # in front of Graph does. Registered with and without a trailing slash.
                'Proxy' { @{ GraphEndpoint = 'https://proxy.contoso.com/graph/' } }
                'ProxyNoSlash' { @{ GraphEndpoint = 'https://proxy.contoso.com/graph' } }
                'ProxyPort' { @{ GraphEndpoint = 'https://proxy.contoso.com:8443/graph/' } }
                default { @{ GraphEndpoint = 'https://graph.microsoft.com/' } }
            }
        }
        Mock Invoke-MgGraphRequest -ModuleName Maester { @{ value = @(@{ id = 'from-graph' }) } }
    }

    AfterEach {
        Remove-Variable -Name MtTestEnvironment -Scope Script -ErrorAction SilentlyContinue
    }

    Context 'Endpoint selection' {
        It 'Sends a relative uri so Microsoft Graph PowerShell routes it to the connected environment' {
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'v1.0/users'
            }
        }

        It 'Keeps the uri relative in <Environment> so no endpoint is hardcoded into the request' -ForEach @(
            @{ Environment = 'China' }
            @{ Environment = 'USGov' }
        ) {
            $script:MtTestEnvironment = $Environment
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'v1.0/users'
            }
        }

        It 'Honors an explicit -GraphBaseUri as an absolute endpoint override' {
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -GraphBaseUri 'https://microsoftgraph.chinacloudapi.cn/' -DisablePaging
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://microsoftgraph.chinacloudapi.cn/v1.0/users'
            }
        }

        It 'Resolves the endpoint on every call instead of reusing the session value' {
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            $script:MtTestEnvironment = 'China'
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'groups' -DisablePaging }
            InModuleScope Maester {
                $__MtSession.GraphBaseUri.AbsoluteUri | Should -Be 'https://microsoftgraph.chinacloudapi.cn/'
            }
        }
    }

    Context 'No Graph connection' {
        It 'Fails with a clear message when there is no Graph context' {
            Mock Get-MgContext -ModuleName Maester { $null }
            InModuleScope Maester {
                { Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging } |
                    Should -Throw '*No active Microsoft Graph context*'
            }
            Should -Not -Invoke Invoke-MgGraphRequest -ModuleName Maester
        }

        It 'Fails with the same message when the context carries no environment' {
            Mock Get-MgContext -ModuleName Maester { @{ Environment = '' } }
            InModuleScope Maester {
                { Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging } |
                    Should -Throw "*Connect-Maester*"
            }
        }

        It 'Still works without a Graph context when -GraphBaseUri is supplied' {
            Mock Get-MgContext -ModuleName Maester { $null }
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -GraphBaseUri 'https://graph.microsoft.us/' -DisablePaging
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.us/v1.0/users'
            }
        }
    }

    Context 'Cache keys' {
        It 'Qualifies the cache key with the resolved endpoint' {
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            InModuleScope Maester {
                $__MtSession.GraphCache.Keys | Should -Contain 'https://graph.microsoft.com/v1.0/users'
            }
        }

        It 'Does not serve a cached response from a different Graph environment' {
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly

            # Same relative uri, different environment: this must reach Graph again.
            $script:MtTestEnvironment = 'China'
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 2 -Exactly

            InModuleScope Maester {
                $__MtSession.GraphCache.Keys | Should -Contain 'https://graph.microsoft.com/v1.0/users'
                $__MtSession.GraphCache.Keys | Should -Contain 'https://microsoftgraph.chinacloudapi.cn/v1.0/users'
            }
        }

        It 'Still serves a second identical request from cache within one environment' {
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly
        }

        It 'Includes query parameters in the cache key' {
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -Select 'displayName' -DisablePaging }
            InModuleScope Maester {
                $__MtSession.GraphCache.Keys | Should -Contain 'https://graph.microsoft.com/v1.0/users?$select=displayName'
            }
        }
    }

    Context 'Methods' {
        It 'Sends a POST with a relative uri and keys the cache by endpoint and body' {
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'security/runHuntingQuery' -Method POST -Body '{"Query":"DeviceInfo"}' -DisablePaging
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -eq 'v1.0/security/runHuntingQuery'
            }
            InModuleScope Maester {
                $__MtSession.GraphCache.Keys | Should -Contain 'https://graph.microsoft.com/v1.0/security/runHuntingQuery_{"Query":"DeviceInfo"}'
            }
        }
    }

    Context 'Paging' {
        It 'Follows an absolute @odata.nextLink unchanged' {
            # Return PSObject, matching Invoke-MgGraphRequest -OutputType PSObject: Format-Result
            # unrolls 'value' through PSObject properties, which a hashtable does not expose.
            Mock Invoke-MgGraphRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'v1.0/users' } {
                [pscustomobject] @{ value = @([pscustomobject] @{ id = 'page1' }); '@odata.nextLink' = 'https://graph.microsoft.com/v1.0/users?$skiptoken=abc' }
            }
            Mock Invoke-MgGraphRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'https://graph.microsoft.com/v1.0/users?$skiptoken=abc' } {
                [pscustomobject] @{ value = @([pscustomobject] @{ id = 'page2' }) }
            }
            $result = InModuleScope Maester { Invoke-MtGraphRequest -RelativeUri 'users' }
            @($result).Count | Should -Be 2
            @($result).id | Should -Be @('page1', 'page2')
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://graph.microsoft.com/v1.0/users?$skiptoken=abc'
            }
        }
    }

    Context 'Batching' {
        It 'Posts to a relative $batch endpoint with endpoint free request urls' {
            $script:MtBatchBody = $null
            Mock Invoke-MgGraphRequest -ModuleName Maester {
                $script:MtBatchBody = $Body
                @{ responses = @(
                        @{ id = 0; body = @{ value = @(@{ id = 'a' }) } }
                        @{ id = 1; body = @{ value = @(@{ id = 'b' }) } }
                    )
                }
            }
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users', 'groups' -DisablePaging }

            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -eq 'v1.0/$batch'
            }
            $requests = ($script:MtBatchBody | ConvertFrom-Json).requests
            $requests.url | Should -Be @('users', 'groups')
            # No request url may carry an absolute endpoint, or batching would pin a cloud.
            foreach ($url in $requests.url) { $url | Should -Not -Match '^https?://' }
        }
    }

    Context 'Endpoint resolution' {
        It 'Resolves the context and the endpoint on every call, so neither can go stale' {
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging
                $null = Invoke-MtGraphRequest -RelativeUri 'groups' -DisablePaging
                $null = Invoke-MtGraphRequest -RelativeUri 'applications' -DisablePaging
            }
            # Both are read per call. The context is what makes a mid-session switch visible,
            # and the endpoint is what makes a change to an existing environment visible.
            Should -Invoke Get-MgContext -ModuleName Maester -Times 3 -Exactly
            Should -Invoke Get-MgEnvironment -ModuleName Maester -Times 3 -Exactly
        }

        It 'Picks up an endpoint changed under the same environment name' {
            # Add-MgEnvironment and Set-MgEnvironment can change the endpoint of an existing
            # name. Resolving per call is what keeps the next request, and the absolute cache
            # key it is stored under, on the new endpoint instead of the previous one.
            $script:MtTestEndpoint = 'https://graph.microsoft.com/'
            Mock Get-MgEnvironment -ModuleName Maester { @{ GraphEndpoint = $script:MtTestEndpoint } }

            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            InModuleScope Maester { $__MtSession.GraphBaseUri.AbsoluteUri | Should -Be 'https://graph.microsoft.com/' }

            $script:MtTestEndpoint = 'https://graph.microsoft.us/'
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            InModuleScope Maester {
                $__MtSession.GraphBaseUri.AbsoluteUri | Should -Be 'https://graph.microsoft.us/'
                # The response is keyed per endpoint, so the second request is not answered
                # from the first endpoint's entry.
                @($__MtSession.GraphCache.Keys) | Should -Contain 'https://graph.microsoft.us/v1.0/users'
            }
        }

        It 'Looks the endpoint up again when the context moves to another environment' {
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            $script:MtTestEnvironment = 'USGov'
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Get-MgEnvironment -ModuleName Maester -Times 2 -Exactly
            InModuleScope Maester {
                $__MtSession.GraphBaseUri.AbsoluteUri | Should -Be 'https://graph.microsoft.us/'
            }
        }

        It 'Does not look the endpoint up at all when the caller overrides it' {
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -GraphBaseUri 'https://graph.microsoft.us/' -DisablePaging
            }
            Should -Not -Invoke Get-MgEnvironment -ModuleName Maester
        }
    }

    Context 'Base uri with a path of its own' {
        # A -GraphBaseUri can carry a path, for example a reverse proxy in front of Graph. The base
        # and the api version then have to come off the subrequest urls together.
        It 'Keeps the path in the absolute transport uri of a single request' {
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -GraphBaseUri 'https://proxy.contoso.com/graph/' -DisablePaging
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://proxy.contoso.com/graph/v1.0/users'
            }
        }

        It 'Strips the base path and the api version from batch subrequest urls' {
            $script:MtBatchBody = $null
            Mock Invoke-MgGraphRequest -ModuleName Maester {
                $script:MtBatchBody = $Body
                @{ responses = @(
                        @{ id = 0; body = @{ value = @(@{ id = 'a' }) } }
                        @{ id = 1; body = @{ value = @(@{ id = 'b' }) } }
                    )
                }
            }
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users', 'groups' -GraphBaseUri 'https://proxy.contoso.com/graph/' -DisablePaging
            }

            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -eq 'https://proxy.contoso.com/graph/v1.0/$batch'
            }
            $requests = ($script:MtBatchBody | ConvertFrom-Json).requests
            # Not 'graph/v1.0/users': the batch itself already posts to the versioned base.
            $requests.url | Should -Be @('users', 'groups')
        }

        It 'Strips the base path when the base uri has no trailing slash' {
            $script:MtBatchBody = $null
            Mock Invoke-MgGraphRequest -ModuleName Maester {
                $script:MtBatchBody = $Body
                @{ responses = @(@{ id = 0; body = @{ value = @() } }, @{ id = 1; body = @{ value = @() } }) }
            }
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users', 'groups' -GraphBaseUri 'https://proxy.contoso.com/graph' -DisablePaging
            }
            $requests = ($script:MtBatchBody | ConvertFrom-Json).requests
            $requests.url | Should -Be @('users', 'groups')
        }

        It 'Sends an absolute uri when the environment endpoint carries a path, because a relative one loses it' -ForEach @(
            @{ Environment = 'Proxy' }
            @{ Environment = 'ProxyNoSlash' }
        ) {
            # Measured against Microsoft.Graph.Authentication 2.41.2 by calling
            # InvokeMgGraphRequest.PrepareUri directly: a relative uri is rebuilt from the base
            # address's scheme and host only, so 'v1.0/users' against an endpoint of
            # https://proxy.contoso.com/graph/ is sent to /v1.0/users and the proxy path is gone.
            # Absolute is the only form that survives, and the endpoint it names is the one just
            # resolved from the live context, so nothing is pinned that the context did not say.
            $script:MtTestEnvironment = $Environment
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://proxy.contoso.com/graph/v1.0/users'
            }
        }

        It 'Keeps an explicit port, which a relative uri also drops' {
            $script:MtTestEnvironment = 'ProxyPort'
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Uri -eq 'https://proxy.contoso.com:8443/graph/v1.0/users'
            }
        }

        It 'Still sends a relative uri for a bare host on the default port, which every Microsoft cloud is' {
            # The property this change exists for: no published endpoint is written into the
            # request, so the SDK routes it to whatever environment is connected.
            foreach ($env in @('Global', 'China', 'USGov')) {
                $script:MtTestEnvironment = $env
                InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users' -DisablePaging }
            }
            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -ParameterFilter { $Uri -eq 'v1.0/users' } -Times 3 -Exactly
        }

        It 'Posts a batch to the absolute versioned root when the environment endpoint has a path' {
            $script:MtBatchBody = $null
            Mock Invoke-MgGraphRequest -ModuleName Maester {
                $script:MtBatchBody = $Body
                @{ responses = @(@{ id = 0; body = @{ value = @() } }, @{ id = 1; body = @{ value = @() } }) }
            }
            $script:MtTestEnvironment = 'Proxy'
            InModuleScope Maester { $null = Invoke-MtGraphRequest -RelativeUri 'users', 'groups' -DisablePaging }

            Should -Invoke Invoke-MgGraphRequest -ModuleName Maester -Times 1 -Exactly -ParameterFilter {
                $Method -eq 'POST' -and $Uri -eq 'https://proxy.contoso.com/graph/v1.0/$batch'
            }
            # The subrequest urls stay relative to the versioned root, which is what the batch
            # endpoint expects, and carry neither the host nor the proxy path.
            $requests = ($script:MtBatchBody | ConvertFrom-Json).requests
            $requests.url | Should -Be @('users', 'groups')
        }

        It 'Keeps unique ids and query parameters in the subrequest url' {
            $script:MtBatchBody = $null
            Mock Invoke-MgGraphRequest -ModuleName Maester {
                $script:MtBatchBody = $Body
                @{ responses = @(@{ id = 0; body = @{ value = @() } }, @{ id = 1; body = @{ value = @() } }) }
            }
            InModuleScope Maester {
                $null = Invoke-MtGraphRequest -RelativeUri 'users' -UniqueId 'a@contoso.com', 'b@contoso.com' -Select 'displayName' -GraphBaseUri 'https://proxy.contoso.com/graph/' -DisablePaging
            }
            $requests = ($script:MtBatchBody | ConvertFrom-Json).requests
            $requests.url | Should -Be @('users/a@contoso.com?$select=displayName', 'users/b@contoso.com?$select=displayName')
        }
    }
}
