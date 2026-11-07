BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'MT.1255 and MT.1256 complete governed group classification' {
    BeforeEach {
        InModuleScope Maester {
            $script:cleanGroupId = '11111111-1111-1111-1111-111111111111'
            $script:driftGroupId = '22222222-2222-2222-2222-222222222222'
            $script:groupResponses = @(
                @{ id = $script:cleanGroupId; isAssignableToRole = $true }
                @{ id = $script:driftGroupId; isAssignableToRole = $true }
            )
            $script:driftSummaries = @(@{
                resource = @{ identifier = $script:driftGroupId; type = 'group'; displayName = 'Drifted privileged group'; catalogId = 'catalog-1' }
                driftCounts = @{ unauthorized = 1; missing = 0; total = 1 }
                details = @()
            })
            Mock Invoke-MtGraphRequest {
                switch ($RelativeUri) {
                    'identityGovernance/insights/accessDriftSummary' { $script:driftSummaries }
                    'identityGovernance/entitlementManagement/catalogs' { @{ id = 'catalog-1' } }
                    'identityGovernance/entitlementManagement/catalogs/catalog-1/resources' {
                        @{ originId = $script:cleanGroupId; originSystem = 'AadGroup' }
                        @{ originId = $script:driftGroupId; originSystem = 'AadGroup' }
                    }
                    'groups' { $script:groupResponses }
                    default { throw "Unexpected Graph call: $RelativeUri" }
                }
            }
            Mock Add-MtTestResultDetail { }
        }
    }

    It 'Fails when both privileged groups resolve and one has unauthorized access' {
        InModuleScope Maester {
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeFalse
        }
    }

    It 'Passes when governed privileged groups resolve and none has drift' {
        InModuleScope Maester {
            $script:driftSummaries = @()
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeTrue
        }
    }

    It 'Separates complete mixed ordinary and privileged group responses correctly' {
        InModuleScope Maester {
            $script:groupResponses[1].isAssignableToRole = $false
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeTrue
            Test-MtAccessPackageDrift -Scope Group | Should -BeFalse
        }
    }

    It 'Passes ordinary governed groups when complete classification shows no drift' {
        InModuleScope Maester {
            $script:driftSummaries = @()
            $script:groupResponses[0].isAssignableToRole = $false
            $script:groupResponses[1].isAssignableToRole = $false
            Test-MtAccessPackageDrift -Scope Group | Should -BeTrue
        }
    }

    It 'Treats a <Response> isAssignableToRole as an ordinary group' -ForEach @(
        @{ Response = 'null' }, @{ Response = 'missing' }
    ) {
        InModuleScope Maester -Parameters @{ Response = $Response } {
            param($Response)
            if ($Response -eq 'null') { $script:groupResponses[1].isAssignableToRole = $null }
            else { $script:groupResponses[1].Remove('isAssignableToRole') }
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeTrue
            Test-MtAccessPackageDrift -Scope Group | Should -BeFalse
        }
    }

    It 'Skips an empty governed scope rather than classifying an empty response as success' {
        InModuleScope Maester {
            $script:driftSummaries = @()
            Mock Invoke-MtGraphRequest { @() } -ParameterFilter { $RelativeUri -eq 'identityGovernance/entitlementManagement/catalogs' }
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' }
            Should -Invoke Invoke-MtGraphRequest -Times 0 -Exactly -ParameterFilter { $RelativeUri -eq 'groups' }
        }
    }

    It 'Never passes either scope for a <Response> group response' -ForEach @(
        @{ Response = 'mixed success and error' }, @{ Response = 'empty' },
        @{ Response = 'missing group' }, @{ Response = 'string classification' },
        @{ Response = 'duplicate group' }, @{ Response = 'unexpected ID' },
        @{ Response = 'error only' }, @{ Response = 'null body' }
    ) {
        InModuleScope Maester -Parameters @{ Response = $Response } {
            param($Response)
            switch ($Response) {
                'mixed success and error' { $script:groupResponses = @($script:groupResponses[0], @{ error = @{ code = 'Authorization_RequestDenied' } }) }
                'empty' { $script:groupResponses = @() }
                'missing group' { $script:groupResponses = @($script:groupResponses[0]) }
                'string classification' { $script:groupResponses[1].isAssignableToRole = 'false' }
                'duplicate group' { $script:groupResponses += $script:groupResponses[1] }
                'unexpected ID' { $script:groupResponses[1].id = '33333333-3333-3333-3333-333333333333' }
                'error only' { $script:groupResponses = @(@{ error = @{ code = 'NotFound' } }) }
                'null body' { $script:groupResponses = @($null) }
            }
            { Test-MtAccessPackageDrift -Scope RoleAssignableGroup } | Should -Throw '*Could not classify governed group*'
            { Test-MtAccessPackageDrift -Scope Group } | Should -Throw '*Could not classify governed group*'
            Should -Invoke Add-MtTestResultDetail -Times 0 -Exactly
        }
    }

    It 'Treats a deleted governed group (batch 404) as not role-assignable instead of failing the run' {
        InModuleScope Maester {
            $script:groupResponses = @($script:groupResponses[0], @{ error = @{ code = 'Request_ResourceNotFound'; message = 'Resource does not exist.' } })
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeTrue
            Test-MtAccessPackageDrift -Scope Group | Should -BeFalse
        }
    }

    It 'Errors when 404 responses do not account for exactly the missing groups' {
        InModuleScope Maester {
            $script:groupResponses = @(
                $script:groupResponses[0]
                @{ error = @{ code = 'Request_ResourceNotFound' } }
                @{ error = @{ code = 'Request_ResourceNotFound' } }
            )
            { Test-MtAccessPackageDrift -Scope RoleAssignableGroup } | Should -Throw '*Could not classify governed groups*'
        }
    }

    It 'Verifies only the three omitted groups in a batch of 74 and accepts confirmed deletions' {
        InModuleScope Maester {
            $script:allGroupIds = @(1..74 | ForEach-Object { '00000000-0000-0000-0000-{0:d12}' -f $_ })
            $script:missingGroupIds = @($script:allGroupIds[-3..-1])
            $script:driftSummaries = @()
            $script:groupResponses = @($script:allGroupIds | Where-Object { $_ -notin $script:missingGroupIds } |
                    ForEach-Object { @{ id = $_; isAssignableToRole = $true } })
            Mock Invoke-MtGraphRequest {
                $script:allGroupIds | ForEach-Object { @{ originId = $_; originSystem = 'AadGroup' } }
            } -ParameterFilter { $RelativeUri -eq 'identityGovernance/entitlementManagement/catalogs/catalog-1/resources' }
            Mock Invoke-MtGraphRequest {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not found', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound))
            } -ParameterFilter { $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 1 -and $UniqueId[0] -in $script:missingGroupIds }

            Test-MtAccessPackageDrift -Scope RoleAssignableGroup | Should -BeTrue

            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter { $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 74 }
            Should -Invoke Invoke-MtGraphRequest -Times 3 -Exactly -ParameterFilter {
                $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 1 -and $UniqueId[0] -in $script:missingGroupIds -and -not $DisableCache
            }
        }
    }

    It 'Recovers an omitted privileged group before evaluating the <Scope> scope' -ForEach @(
        @{ Scope = 'RoleAssignableGroup'; Expected = $false }
        @{ Scope = 'Group'; Expected = $true }
    ) {
        InModuleScope Maester -Parameters @{ Scope = $Scope; Expected = $Expected } {
            param($Scope, $Expected)
            $script:groupResponses = @($script:groupResponses[0])
            $script:groupResponses[0].isAssignableToRole = $false
            Mock Invoke-MtGraphRequest {
                @{ id = $script:driftGroupId; isAssignableToRole = $true }
            } -ParameterFilter { $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 1 -and $UniqueId[0] -eq $script:driftGroupId }

            Test-MtAccessPackageDrift -Scope $Scope | Should -Be $Expected

            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 1 -and $UniqueId[0] -eq $script:driftGroupId -and -not $DisableCache
            }
        }
    }

    It 'Does not treat an omitted group as deleted when its individual lookup returns HTTP <Status>' -ForEach @(
        @{ Status = 403 }, @{ Status = 503 }
    ) {
        InModuleScope Maester -Parameters @{ Status = $Status } {
            param($Status)
            $script:groupResponses = @($script:groupResponses[0])
            Mock Invoke-MtGraphRequest {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Group lookup failed', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$Status))
            } -ParameterFilter { $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 1 }

            { Test-MtAccessPackageDrift -Scope RoleAssignableGroup } | Should -Throw '*Group lookup failed*'
            { Test-MtAccessPackageDrift -Scope Group } | Should -Throw '*Group lookup failed*'
            Should -Invoke Add-MtTestResultDetail -Times 0 -Exactly
        }
    }

    It 'Names the Graph error code when a group cannot be read' {
        InModuleScope Maester {
            $script:groupResponses = @($script:groupResponses[0], @{ error = @{ code = 'Authorization_RequestDenied'; message = 'Insufficient privileges.' } })
            { Test-MtAccessPackageDrift -Scope RoleAssignableGroup } | Should -Throw '*Authorization_RequestDenied: Insufficient privileges.*'
        }
    }

    It 'Treats a single deleted governed group (unbatched 404) as not role-assignable' {
        InModuleScope Maester {
            $script:driftSummaries = @()
            Mock Invoke-MtGraphRequest { @{ originId = $script:driftGroupId; originSystem = 'AadGroup' } } -ParameterFilter {
                $RelativeUri -eq 'identityGovernance/entitlementManagement/catalogs/catalog-1/resources'
            }
            Mock Invoke-MtGraphRequest {
                throw [Microsoft.PowerShell.Commands.HttpResponseException]::new('Not found', [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]::NotFound))
            } -ParameterFilter { $RelativeUri -eq 'groups' }
            Test-MtAccessPackageDrift -Scope Group | Should -BeTrue
        }
    }

    It 'Requests a group once when its ID differs only in case' {
        InModuleScope Maester {
            $script:driftSummaries[0].resource.identifier = $script:driftGroupId.ToUpperInvariant()
            $script:groupResponses[1].isAssignableToRole = $false
            Test-MtAccessPackageDrift -Scope Group | Should -BeFalse
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter { $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 2 }
        }
    }

    It 'Does not discard malformed governed group identifiers before classifying' {
        InModuleScope Maester {
            $script:driftGroupId = 'not-a-guid'
            { Test-MtAccessPackageDrift -Scope RoleAssignableGroup } | Should -Throw '*not a group object ID*'
        }
    }

    It 'Propagates a terminating group lookup error' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest { throw 'Group request failed' } -ParameterFilter { $RelativeUri -eq 'groups' }
            { Test-MtAccessPackageDrift -Scope RoleAssignableGroup } | Should -Throw '*Group request failed*'
        }
    }

    It 'Does not require classification of explicitly excluded resources' {
        InModuleScope Maester {
            $script:groupResponses = @($script:groupResponses[0])
            Test-MtAccessPackageDrift -Scope RoleAssignableGroup -ExcludedResourceId $script:driftGroupId | Should -BeTrue
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'groups' -and @($UniqueId).Count -eq 1 -and $UniqueId -contains $script:cleanGroupId
            }
        }
    }
}

Describe 'MT.1257 governed application drift' {
    BeforeEach {
        InModuleScope Maester {
            $script:appId = '44444444-4444-4444-4444-444444444444'
            $script:catalogResources = @(
                @{ originId = $script:appId; originSystem = 'AadApplication' }
                @{ originId = '11111111-1111-1111-1111-111111111111'; originSystem = 'AadGroup' }
            )
            $script:driftSummaries = @(@{
                resource = @{ identifier = $script:appId; type = 'application'; displayName = 'Payroll'; catalogId = 'catalog-1' }
                driftCounts = @{ unauthorized = 2; missing = 0; total = 2 }
                details = @()
            })
            Mock Invoke-MtGraphRequest {
                switch ($RelativeUri) {
                    'identityGovernance/insights/accessDriftSummary' { $script:driftSummaries }
                    'identityGovernance/entitlementManagement/catalogs' { @{ id = 'catalog-1' } }
                    'identityGovernance/entitlementManagement/catalogs/catalog-1/resources' { $script:catalogResources }
                    default { throw "Unexpected Graph call: $RelativeUri" }
                }
            }
            Mock Add-MtTestResultDetail { }
        }
    }

    It 'Fails on unauthorized app role assignments and requests only application drift' {
        InModuleScope Maester {
            Test-MtAccessPackageDrift -Scope Application | Should -BeFalse
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'identityGovernance/insights/accessDriftSummary' -and $Filter -like "resource/type eq 'application'*"
            }
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like '*Payroll*' -and $Result -like '*app role assignments*' }
        }
    }

    It 'Links the drifted application with the shared service principal template' {
        InModuleScope Maester {
            $portalUrl = $__MtSession.AdminPortalUrl
            try {
                $__MtSession.AdminPortalUrl = @{ Entra = 'https://entra.microsoft.com/' }
                Test-MtAccessPackageDrift -Scope Application | Should -BeFalse
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                    $Result.Contains("[Payroll]($((Get-MtPortalLinkTemplate).LinkTemplates.ServicePrincipals -f $script:appId))")
                }
            } finally {
                $__MtSession.AdminPortalUrl = $portalUrl
            }
        }
    }

    It 'Passes governed applications without drift' {
        InModuleScope Maester {
            $script:driftSummaries = @()
            Test-MtAccessPackageDrift -Scope Application | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like 'Well done.*1 governed application.' }
        }
    }

    It 'Skips when no application is a resource of a catalog' {
        InModuleScope Maester {
            $script:driftSummaries = @()
            $script:catalogResources = @($script:catalogResources[1])
            Test-MtAccessPackageDrift -Scope Application | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -like '*enterprise application*' }
        }
    }

    It 'Fails missing app role assignments only while IncludeMissingAccess is set' {
        InModuleScope Maester {
            $script:driftSummaries[0].driftCounts = @{ unauthorized = 0; missing = 1; total = 1 }
            Test-MtAccessPackageDrift -Scope Application | Should -BeFalse
            Test-MtAccessPackageDrift -Scope Application -IncludeMissingAccess $false | Should -BeTrue
        }
    }

    It 'Is run by MT.1257 with its parameters' {
        InModuleScope Maester {
            Mock Test-MtAccessPackageDrift { $true }
            Test-MtAccessPackageDriftApplication -IncludeMissingAccess $false -ExcludedResourceId $script:appId -MaxResources 5 | Should -BeTrue
            Should -Invoke Test-MtAccessPackageDrift -Times 1 -Exactly -ParameterFilter {
                $Scope -eq 'Application' -and -not $IncludeMissingAccess -and $ExcludedResourceId -contains $script:appId -and $MaxResources -eq 5
            }
        }
    }
}
