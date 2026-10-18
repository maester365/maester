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
}
