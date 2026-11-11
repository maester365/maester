BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'MT.1258 GDAP and Tenant Governance assessment with optional enrichment' {
    BeforeEach {
        InModuleScope Maester {
            $script:ownTenantId = '11111111-1111-1111-1111-111111111111'
            $script:adminTenantId = '22222222-2222-2222-2222-222222222222'
            $script:failedSources = @()
            $script:governanceRelationships = @()
            $script:remoteGroups = @()
            $script:roleAssignments = @()
            $script:partners = @()
            $script:serviceProviders = @()
            $script:skus = @()
            $script:relatedTenants = @()
            $script:auditEvents = @()
            Mock Get-MtSetting { @() }
            Mock Get-MgContext { [pscustomobject]@{ Environment = 'Global' } }
            Mock Add-MtTestResultDetail { }
            Mock Invoke-MtGraphRequest {
                if ($RelativeUri -in $script:failedSources) { throw "Source unavailable: $RelativeUri" }
                switch ($RelativeUri) {
                    'organization' { @{ id = $script:ownTenantId } }
                    'directory/tenantGovernance/governanceRelationships' { $script:governanceRelationships }
                    'directory/remoteTenantGroups' { $script:remoteGroups }
                    'directory/partners' { $script:partners }
                    'policies/crossTenantAccessPolicy/partners' { $script:serviceProviders }
                    'subscribedSkus' { $script:skus }
                    'directory/tenantGovernance/relatedTenants' { $script:relatedTenants }
                    'roleManagement/directory/roleAssignments' { $script:roleAssignments }
                    # Requested with -DisablePaging, which returns the raw response with the events in .value.
                    'auditLogs/directoryAudits' { [pscustomobject]@{ value = @($script:auditEvents) } }
                    'roleManagement/directory/roleDefinitions' {
                        @{ id = 'role-1'; displayName = 'Global Administrator'; isPrivileged = $true }
                    }
                    default { @() }
                }
            }
        }
    }

    It 'Passes when every source is readable and no tenant has access' {
        InModuleScope Maester {
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate -and $Result -like 'Well done.*' }
        }
    }

    It 'Investigates remote tenant groups failure even when all other sources are empty' {
        InModuleScope Maester {
            $script:failedSources = @('directory/remoteTenantGroups')
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                $Investigate -and $Result -like '*remote tenant groups could not be read*'
            }
        }
    }

    It 'Investigates rather than passes when an unclassified role holder lacks principalOrganizationId' {
        InModuleScope Maester {
            $script:failedSources = @('directory/remoteTenantGroups')
            $script:roleAssignments = @(@{ principalId = 'remote-group'; roleDefinitionId = 'role-1'; directoryScopeId = '/' })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate }
        }
    }

    It 'Assesses a GDAP partner through remote groups without requiring a service provider mark or role assignment' {
        InModuleScope Maester {
            $script:remoteGroups = @(@{ id = 'remote-group'; remoteGroupId = 'partner-group'; remoteTenantId = $script:adminTenantId; displayName = 'Partner admins' })
            Test-MtCrossTenantAdministrationRelationship | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate -and $Result -like '*Not allowlisted*' }
        }
    }

    It 'Does not assess an unrelated foreign role holder even when marked as a service provider' {
        InModuleScope Maester {
            $script:roleAssignments = @(@{ principalId = 'remote-group'; principalOrganizationId = $script:adminTenantId; roleDefinitionId = 'role-1'; directoryScopeId = '/' })
            $script:serviceProviders = @(@{ tenantId = $script:adminTenantId; isServiceProvider = $true })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*Service providers in cross-tenant access settings*' -and $Result -notlike '*Not allowlisted*'
            }
        }
    }

    It 'Passes an allowlisted GDAP partner only when assessment sources are readable' {
        InModuleScope Maester {
            Mock Get-MtSetting { @($script:adminTenantId) } -ParameterFilter { $Name -eq 'DelegatedAdminTenants' }
            $script:remoteGroups = @(@{ id = 'remote-group'; remoteTenantId = $script:adminTenantId })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate }
            $script:failedSources = @('directory/remoteTenantGroups')
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Investigate }
        }
    }

    It 'Matches allowlist entries written with braces or without hyphens' {
        InModuleScope Maester {
            Mock Get-MtSetting { @('{22222222-2222-2222-2222-222222222222}', '33333333333333333333333333333333') } -ParameterFilter { $Name -eq 'DelegatedAdminTenants' }
            $script:remoteGroups = @(
                @{ id = 'remote-group-1'; remoteTenantId = $script:adminTenantId }
                @{ id = 'remote-group-2'; remoteTenantId = '33333333-3333-3333-3333-333333333333' }
            )
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate -and $Result -notlike '*Not allowlisted*' }
        }
    }

    It 'Preserves known governance failure despite remote group and enrichment failures' {
        InModuleScope Maester {
            $script:failedSources = @('directory/remoteTenantGroups', 'policies/crossTenantAccessPolicy/partners', 'directory/partners', 'roleManagement/directory/roleAssignments')
            $script:governanceRelationships = @(@{
                    id = 'relationship-1'; status = 'active'; governedTenantId = $script:ownTenantId
                    governingTenantId = $script:adminTenantId; governingTenantName = 'Unapproved administrator'
                })
            Test-MtCrossTenantAdministrationRelationship | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate -and $Result -like '*Not allowlisted*' }
        }
    }

    It 'Errors when both assessment sources fail even when enrichment sources are readable' {
        InModuleScope Maester {
            $script:failedSources = @('directory/remoteTenantGroups', 'directory/tenantGovernance/governanceRelationships')
            { Test-MtCrossTenantAdministrationRelationship } | Should -Throw '*None of the relationship sources could be read*'
        }
    }

    It 'Does not treat legacy DAP or CSP partner metadata as GDAP even with a service provider mark' {
        InModuleScope Maester {
            $script:partners = @(@{ partnerTenantId = $script:adminTenantId; companyType = 'resellerPartnerDelegatedAdmin'; roleIds = @('role-1') })
            $script:serviceProviders = @(@{ tenantId = $script:adminTenantId; isServiceProvider = $true })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*Legacy DAP roles*' -and $Result -like '*Informational only; no GDAP established*' -and $Result -notlike '*Not allowlisted*'
            }
        }
    }

    It 'Keeps a service provider mark informational for a former governing tenant' {
        InModuleScope Maester {
            $script:governanceRelationships = @(@{
                    id = 'old-relationship'; status = 'terminated'; governedTenantId = $script:ownTenantId
                    governingTenantId = $script:adminTenantId
                })
            $script:serviceProviders = @(@{ tenantId = $script:adminTenantId; isServiceProvider = $true })
            $script:partners = @(@{ partnerTenantId = $script:adminTenantId })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*Former Tenant Governance*' -and $Result -notlike '*Not allowlisted*'
            }
        }
    }

    It 'Fails a governing tenant whose relationship is pending termination' {
        InModuleScope Maester {
            $script:governanceRelationships = @(@{
                    id = 'pending'; status = 'terminationRequestedByGoverningTenant'; governedTenantId = $script:ownTenantId
                    governingTenantId = $script:adminTenantId; governingTenantName = 'Governing tenant'
                })
            Test-MtCrossTenantAdministrationRelationship | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*1 through Tenant Governance*' -and $Result -like '*terminationRequestedByGoverningTenant*'
            }
        }
    }

    It 'Does not assess an outbound relationship in which this tenant governs another tenant' {
        InModuleScope Maester {
            $script:governanceRelationships = @(@{
                    id = 'outbound'; status = 'active'; governingTenantId = $script:ownTenantId; governedTenantId = $script:adminTenantId
                })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { -not $Investigate -and $Result -like 'Well done.*' }
        }
    }

    It 'Investigates remote groups still exposed for a former governing tenant' {
        InModuleScope Maester {
            $script:governanceRelationships = @(@{
                    id = 'old-relationship'; status = 'terminated'; governedTenantId = $script:ownTenantId
                    governingTenantId = $script:adminTenantId
                })
            $script:remoteGroups = @(@{ id = 'remote-group'; remoteTenantId = $script:adminTenantId })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                $Investigate -and $Result -like '*remote tenant groups are still exposed*'
            }
        }
    }

    It 'Does not count an active governing tenant again as GDAP' {
        InModuleScope Maester {
            $script:governanceRelationships = @(@{
                    id = 'relationship'; status = 'active'; governedTenantId = $script:ownTenantId
                    governingTenantId = $script:adminTenantId
                })
            $script:remoteGroups = @(@{ id = 'remote-group'; remoteTenantId = $script:adminTenantId })
            Test-MtCrossTenantAdministrationRelationship | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*1 through Tenant Governance*' -and $Result -notlike '*1 through GDAP*'
            }
        }
    }

    It 'Assesses remote groups of a tenant that this tenant governs as GDAP' {
        InModuleScope Maester {
            $script:governanceRelationships = @(@{
                    id = 'outbound'; status = 'active'; governingTenantId = $script:ownTenantId
                    governedTenantId = $script:adminTenantId
                })
            $script:remoteGroups = @(@{ id = 'remote-group'; remoteTenantId = $script:adminTenantId })
            Test-MtCrossTenantAdministrationRelationship | Should -BeFalse
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*1 through GDAP*'
            }
        }
    }

    It 'Does not change the verdict when informational sources fail' {
        InModuleScope Maester {
            $script:failedSources = @('policies/crossTenantAccessPolicy/partners', 'directory/partners', 'roleManagement/directory/roleAssignments')
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*cross-tenant access partners could not be read*' -and
                $Result -like '*CSP partner information could not be read*' -and $Result -like '*directory role information could not be read*'
            }
        }
    }

    It 'Skips discovery without a Governance licence but still assesses relationships' {
        InModuleScope Maester {
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Invoke-MtGraphRequest -Times 0 -Exactly -ParameterFilter { $RelativeUri -eq 'directory/tenantGovernance/relatedTenants' }
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter { $RelativeUri -eq 'directory/tenantGovernance/governanceRelationships' }
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*discovery was skipped because the tenant has no*'
            }
        }
    }

    It 'Does not request licences or discovery when explicitly disabled' {
        InModuleScope Maester {
            Test-MtCrossTenantAdministrationRelationship -IncludeTenantDiscovery $false | Should -BeTrue
            Should -Invoke Invoke-MtGraphRequest -Times 0 -Exactly -ParameterFilter {
                $RelativeUri -in @('subscribedSkus', 'directory/tenantGovernance/relatedTenants')
            }
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*discovery is disabled by IncludeTenantDiscovery*'
            }
        }
    }

    It 'Reports unknown licensing without treating it as absent or changing the verdict' {
        InModuleScope Maester {
            $script:failedSources = @('subscribedSkus')
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Invoke-MtGraphRequest -Times 0 -Exactly -ParameterFilter { $RelativeUri -eq 'directory/tenantGovernance/relatedTenants' }
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*licensing could not be confirmed*' -and $Result -notlike '*tenant has no Microsoft Entra ID Governance licence*'
            }
        }
    }

    It 'Includes licensed inbound admin-app metrics by default without assessing activity-only tenants' {
        InModuleScope Maester {
            $script:skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanId = 'e866a266-3cff-43a3-acca-0c90a7e00c8b' }) })
            $script:relatedTenants = @(@{
                    id                          = $script:adminTenantId
                    appB2BSignInActivityMetrics = @{ recent = @{ inboundMonthlyTotalUsers = 12; inboundMonthlyTotalApplications = 3 } }
                })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter { $RelativeUri -eq 'directory/tenantGovernance/relatedTenants' }
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*12 users*3 admin apps*' -and $Result -like '*Related tenants with inbound admin app sign-ins (information only)*' -and $Result -notlike '*Not allowlisted*'
            }
        }
    }

    It 'Shows inbound metrics for allowlisted GDAP partners as information' {
        InModuleScope Maester {
            Mock Get-MtSetting { @($script:adminTenantId) } -ParameterFilter { $Name -eq 'DelegatedAdminTenants' }
            $script:remoteGroups = @(@{ id = 'remote-group'; remoteTenantId = $script:adminTenantId })
            $script:skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanId = 'e866a266-3cff-43a3-acca-0c90a7e00c8b' }) })
            $script:relatedTenants = @(@{
                    id                          = $script:adminTenantId
                    appB2BSignInActivityMetrics = @{ recent = @{ inboundMonthlyTotalUsers = 7; inboundMonthlyTotalApplications = 2 } }
                })
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*7 users*2 admin apps*' -and $Result -notlike '*Not allowlisted*'
            }
        }
    }

    It 'Reports discovery failures without changing the assessment' {
        InModuleScope Maester {
            $script:skus = @(@{ capabilityStatus = 'Enabled'; servicePlans = @(@{ servicePlanId = 'e866a266-3cff-43a3-acca-0c90a7e00c8b' }) })
            $script:failedSources = @('directory/tenantGovernance/relatedTenants')
            Test-MtCrossTenantAdministrationRelationship | Should -BeTrue
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                -not $Investigate -and $Result -like '*related tenants could not be read*'
            }
        }
    }

    It 'Skips outside the worldwide cloud without calling Graph' {
        InModuleScope Maester {
            Mock Get-MgContext { [pscustomobject]@{ Environment = 'USGov' } }
            Test-MtCrossTenantAdministrationRelationship | Should -BeNullOrEmpty
            Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $SkippedBecause -eq 'Custom' -and $SkippedCustomReason -like '*USGov*' }
            Should -Invoke Invoke-MtGraphRequest -Times 0 -Exactly
        }
    }

    Context 'First recorded change from the audit log' {
        BeforeEach {
            InModuleScope Maester {
                $script:governanceRelationships = @(@{
                        id = 'relationship-1'; status = 'active'; governedTenantId = $script:ownTenantId
                        governingTenantId = $script:adminTenantId; governingTenantName = 'Governing tenant'
                    })
                $script:newAuditEvent = {
                    param([string] $Result, [string] $User, $Date = '2026-10-01T08:00:00Z')
                    [pscustomobject]@{
                        result = $Result; activityDisplayName = 'Update governance relationship'; activityDateTime = $Date
                        initiatedBy = [pscustomobject]@{ user = [pscustomobject]@{ userPrincipalName = $User } }
                    }
                }
            }
        }

        It 'Shows the first successful change and skips a failed attempt before it' {
            InModuleScope Maester {
                $script:auditEvents = @(
                    (& $script:newAuditEvent 'failure' 'attacker@contoso.com')
                    (& $script:newAuditEvent 'success' 'admin@contoso.com')
                )
                $null = Test-MtCrossTenantAdministrationRelationship
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                    $Result -like '*First recorded change (audit log)*' -and $Result -like '*admin\@contoso.com*' -and
                    $Result -notlike '*attacker\@contoso.com*' -and $Result -notlike '*Approved by*'
                }
            }
        }

        It 'Shows a neutral note when the audit log holds no successful change' {
            InModuleScope Maester {
                $script:auditEvents = @(& $script:newAuditEvent 'failure' 'attacker@contoso.com')
                $null = Test-MtCrossTenantAdministrationRelationship
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter {
                    $Result -like '*No successful change found in the audit log*' -and $Result -notlike '*retention)_*'
                }
            }
        }

        It 'Shows an unknown date instead of failing when the event date cannot be read' {
            InModuleScope Maester {
                $script:auditEvents = @(& $script:newAuditEvent 'success' 'admin@contoso.com' $null)
                { $null = Test-MtCrossTenantAdministrationRelationship } | Should -Not -Throw
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like '*admin\@contoso.com*on an unknown date*' }
            }
        }

        It 'Shows that the audit log is not available when it cannot be read' {
            InModuleScope Maester {
                $script:failedSources = @('auditLogs/directoryAudits')
                $null = Test-MtCrossTenantAdministrationRelationship
                Should -Invoke Add-MtTestResultDetail -Times 1 -Exactly -ParameterFilter { $Result -like '*Audit log not available*' }
            }
        }
    }
}
