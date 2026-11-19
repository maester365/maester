Describe 'Test-MtCaGap (MT.1036)' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # The native-test function is not exported; reach it the same way the other native tests do.
        Use-MtModuleFunction -Name Test-MtCaGap

        $script:BreakGlassUser = '11111111-1111-1111-1111-111111111111'
        $script:AgentIdentity = '22222222-2222-2222-2222-222222222222'
        $script:AgentUser = '33333333-3333-3333-3333-333333333333'

        # Builds a Conditional Access policy the way Graph beta returns it.
        function Get-TestPolicy {
            param(
                [string]$Name,
                [string]$State = 'enabled',
                [string[]]$IncludeUsers = @(),
                [string[]]$ExcludeUsers = @(),
                [string[]]$IncludeAgentIdServicePrincipals,
                [string[]]$ExcludeAgentIdServicePrincipals,
                [string[]]$IncludeAgentUsers,
                [string[]]$ExcludeAgentUsers
            )
            $clientApplications = $null
            if ($PSBoundParameters.ContainsKey('IncludeAgentIdServicePrincipals') -or $PSBoundParameters.ContainsKey('ExcludeAgentIdServicePrincipals')) {
                $clientApplications = [pscustomobject]@{
                    includeServicePrincipals        = @()
                    excludeServicePrincipals        = @()
                    includeAgentIdServicePrincipals = @($IncludeAgentIdServicePrincipals)
                    excludeAgentIdServicePrincipals = @($ExcludeAgentIdServicePrincipals)
                }
            }
            $agents = $null
            if ($PSBoundParameters.ContainsKey('IncludeAgentUsers') -or $PSBoundParameters.ContainsKey('ExcludeAgentUsers')) {
                $agents = [pscustomobject]@{
                    includeAgentUsers = @($IncludeAgentUsers)
                    excludeAgentUsers = @($ExcludeAgentUsers)
                    agentFilter       = $null
                }
            }
            [pscustomobject]@{
                id          = [guid]::NewGuid().Guid
                displayName = $Name
                state       = $State
                conditions  = [pscustomobject]@{
                    users              = [pscustomobject]@{
                        includeUsers  = @($IncludeUsers)
                        excludeUsers  = @($ExcludeUsers)
                        includeGroups = @()
                        excludeGroups = @()
                        includeRoles  = @()
                        excludeRoles  = @()
                    }
                    applications       = [pscustomobject]@{ includeApplications = @('All'); excludeApplications = @() }
                    clientApplications = $clientApplications
                    agents             = $agents
                    locations          = $null
                    platforms          = $null
                }
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        Mock -ModuleName Maester Add-MtTestResultDetail { $script:TestResult = $Result }
        # Names resolve by ID; anything not listed fails to resolve.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            switch ($UniqueId) {
                '11111111-1111-1111-1111-111111111111' { return [pscustomobject]@{ displayName = 'breakglass1' } }
                '22222222-2222-2222-2222-222222222222' { return [pscustomobject]@{ displayName = 'Contoso Agent' } }
                '33333333-3333-3333-3333-333333333333' { return [pscustomobject]@{ displayName = 'Contoso Agent User' } }
                default { throw 'Not found' }
            }
        }
    }

    It 'passes when nothing is excluded' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { Get-TestPolicy -Name 'All users MFA' -IncludeUsers 'All' }

        Test-MtCaGap | Should -BeTrue
        $script:TestResult | Should -Match 'All excluded objects seem to have a fallback'
    }

    It 'reports an excluded user with no fallback (existing behaviour)' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { Get-TestPolicy -Name 'All users MFA' -IncludeUsers 'All' -ExcludeUsers $script:BreakGlassUser }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match '(?m)^    User: breakglass1$'
        $script:TestResult | Should -Match "Excluded in policy 'All users MFA'"
    }

    It 'reports an excluded agent identity with no fallback' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agents' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals $script:AgentIdentity
        }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match 'The following agent identity objects did not have a fallback'
        $script:TestResult | Should -Match '(?m)^    Agent identity: Contoso Agent$'
        $script:TestResult | Should -Match "Excluded in policy 'Block risky agents'"
        # Agent identities are looked up as service principals.
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter { $RelativeUri -eq 'servicePrincipals' -and $UniqueId -eq '22222222-2222-2222-2222-222222222222' }
    }

    It 'passes when an excluded agent identity is included by ID in another enabled policy' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agents' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals $script:AgentIdentity
            Get-TestPolicy -Name 'Contoso agent policy' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals $script:AgentIdentity -ExcludeAgentIdServicePrincipals @()
        }

        Test-MtCaGap | Should -BeTrue
    }

    It 'reports an excluded agent user with no fallback' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agent users' -IncludeUsers 'None' -IncludeAgentUsers 'All' -ExcludeAgentUsers $script:AgentUser
        }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match 'The following agent user objects did not have a fallback'
        $script:TestResult | Should -Match '(?m)^    Agent user: Contoso Agent User$'
        $script:TestResult | Should -Match "Excluded in policy 'Block risky agent users'"
        # Agents' user accounts are looked up as users.
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -ParameterFilter { $RelativeUri -eq 'users' -and $UniqueId -eq '33333333-3333-3333-3333-333333333333' }
    }

    It 'passes when an excluded agent user is included by ID in another enabled policy' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agent users' -IncludeUsers 'None' -IncludeAgentUsers 'All' -ExcludeAgentUsers $script:AgentUser
            Get-TestPolicy -Name 'Contoso agent user policy' -IncludeUsers 'None' -IncludeAgentUsers $script:AgentUser -ExcludeAgentUsers @()
        }

        Test-MtCaGap | Should -BeTrue
    }

    It 'does not count an include of All as a fallback for an excluded agent' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agents' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals $script:AgentIdentity
            Get-TestPolicy -Name 'All agents MFA' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals @()
        }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match '(?m)^    Agent identity: Contoso Agent$'
    }

    It 'does not count a service principal or agent user include as a fallback for an excluded agent identity' {
        # An agent identity is a service principal, but the check keeps the three ID lists apart.
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agents' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals $script:AgentIdentity
            $sp = Get-TestPolicy -Name 'Workload identity policy' -IncludeUsers 'None'
            $sp.conditions.clientApplications = [pscustomobject]@{ includeServicePrincipals = @($script:AgentIdentity); excludeServicePrincipals = @() }
            $sp
            Get-TestPolicy -Name 'Agent user policy' -IncludeUsers 'None' -IncludeAgentUsers $script:AgentIdentity -ExcludeAgentUsers @()
        }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match '(?m)^    Agent identity: Contoso Agent$'
    }

    It 'ignores agent exclusions in policies that are not enabled' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Report-only agents' -State 'enabledForReportingButNotEnforced' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals $script:AgentIdentity
            Get-TestPolicy -Name 'Off agent users' -State 'disabled' -IncludeUsers 'None' -IncludeAgentUsers 'All' -ExcludeAgentUsers $script:AgentUser
        }

        Test-MtCaGap | Should -BeTrue
    }

    It 'shows the ID when an agent name cannot be resolved' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'Block risky agents' -IncludeUsers 'None' -IncludeAgentIdServicePrincipals 'All' -ExcludeAgentIdServicePrincipals '44444444-4444-4444-4444-444444444444'
        }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match 'Agent identity: 44444444-4444-4444-4444-444444444444 \(Unable to resolve GUID\)'
    }

    It 'reports user and agent gaps together' {
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-TestPolicy -Name 'All users MFA' -IncludeUsers 'All' -ExcludeUsers $script:BreakGlassUser
            Get-TestPolicy -Name 'Block risky agent users' -IncludeUsers 'None' -IncludeAgentUsers 'All' -ExcludeAgentUsers $script:AgentUser
        }

        Test-MtCaGap | Should -BeFalse
        $script:TestResult | Should -Match '(?m)^    User: breakglass1$'
        $script:TestResult | Should -Match '(?m)^    Agent user: Contoso Agent User$'
    }
}
