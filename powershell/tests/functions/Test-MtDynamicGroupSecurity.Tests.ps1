Describe 'Dynamic group security checks' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force

        function Get-TestDynamicGroup {
            param(
                [string] $Id,
                [string] $Rule,
                [string] $State = 'On',
                [object[]] $Licenses = @()
            )

            return [pscustomobject]@{
                id                            = $Id
                displayName                   = "Group $Id"
                groupTypes                    = @('DynamicMembership')
                membershipRule                = $Rule
                membershipRuleProcessingState = $State
                assignedLicenses              = $Licenses
            }
        }

        function Get-TestCaPolicy {
            param(
                [string] $Id,
                [string[]] $IncludeGroups = @(),
                [string[]] $ExcludeGroups = @()
            )

            return [pscustomobject]@{
                id          = $Id
                displayName = "Policy $Id"
                state       = 'enabled'
                conditions  = [pscustomobject]@{
                    users = [pscustomobject]@{
                        includeGroups = $IncludeGroups
                        excludeGroups = $ExcludeGroups
                    }
                }
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:Investigate = $false
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @() }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $Investigate, $SkippedBecause)

            $script:TestResult = $Result
            $script:Investigate = [bool] $Investigate
            $script:SkippedBecause = $SkippedBecause
        }
        Mock -ModuleName Maester Get-GraphObjectMarkdown {
            param($GraphObjects)

            return "[$($GraphObjects.displayName)]"
        }
    }

    Context 'membership rule analysis' {
        It 'classifies risky, low-risk, and safe properties' {
            InModuleScope Maester {
                $Rule = '(user.department -eq "Finance") -and ' +
                    '(user.userPrincipalName -eq "admin@contoso.com") -and ' +
                    '(user.extensionAttribute4 -eq "Privileged") -and ' +
                    '(user.accountEnabled -eq true)'
                $Analysis = @(Get-MtDynamicGroupRuleAnalysis -MembershipRule $Rule)

                $Analysis.Category | Should -Be @(
                    'RiskyUserInfluenceable', 'LowRiskPrivilegedControlled',
                    'LowRiskPrivilegedControlled', 'Other'
                )
            }
        }

        It 'captures collection operators and pattern matching' {
            InModuleScope Maester {
                $Rule = '(UsEr.proxyAddresses -AnY (_ -StartsWith "SMTP:admin"))'
                $Analysis = @(Get-MtDynamicGroupRuleAnalysis -MembershipRule $Rule)

                $Analysis.Count | Should -Be 1
                $Analysis[0].Operator | Should -Be '-any/-startswith'
                $Analysis[0].UsesPatternMatch | Should -BeTrue
            }
        }

        It 'extracts memberOf source group identifiers' {
            InModuleScope Maester {
                $SourceId = '00000000-0000-0000-0000-000000000000'
                $Rule = "device.memberOf -any (group.objectId -in ['$SourceId'])"
                $Analysis = @(Get-MtDynamicGroupRuleAnalysis -MembershipRule $Rule)

                $Analysis[0].Category | Should -Be 'MemberOf'
                $Analysis[0].ReferencedGroupIds | Should -Be $SourceId
            }
        }

        It 'returns no analysis for empty or malformed rules' {
            InModuleScope Maester {
                @(Get-MtDynamicGroupRuleAnalysis -MembershipRule $null).Count | Should -Be 0
                @(Get-MtDynamicGroupRuleAnalysis -MembershipRule 'not a rule').Count |
                    Should -Be 0
            }
        }
    }

    Context 'Conditional Access correlation' {
        It 'reports include and exclude references case-insensitively' {
            $Policies = @(
                Get-TestCaPolicy -Id 'include' -IncludeGroups @('GROUP-1')
                Get-TestCaPolicy -Id 'exclude' -ExcludeGroups @('group-1')
            )
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $Policies }

            $References = InModuleScope Maester {
                @(Get-MtDynamicGroupCaReference -GroupId 'group-1')
            }

            $References.Count | Should -Be 2
            $References.Condition | Should -Be @('Include', 'Exclude')
        }

        It 'throws when policy retrieval fails' {
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { throw 'Unavailable' }

            {
                InModuleScope Maester {
                    Get-MtDynamicGroupCaReference -GroupId 'group-1'
                }
            } | Should -Throw -ExpectedMessage '*Unavailable*'
        }
    }

    Context 'user-influenceable and privileged-controlled attributes' {
        It 'passes when no candidate properties are used' {
            $Groups = @(Get-TestDynamicGroup -Id 'safe' `
                    -Rule '(user.accountEnabled -eq true)')
            Mock -ModuleName Maester Invoke-MtGraphRequest { return $Groups }

            Test-MtDynamicGroupUserControlledAttributes | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
            $script:Investigate | Should -BeFalse
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
                -ParameterFilter {
                $RelativeUri -eq 'groups' -and
                $Filter -eq "groupTypes/any(groupType:groupType eq 'DynamicMembership')" -and
                $QueryParameters['$count'] -eq 'true' -and
                @($Select).Count -eq 6 -and
                $Select -contains 'id' -and
                $Select -contains 'displayName' -and
                $Select -contains 'groupTypes' -and
                $Select -contains 'membershipRule' -and
                $Select -contains 'membershipRuleProcessingState' -and
                $Select -contains 'assignedLicenses'
            }
        }

        It 'marks candidate rules for investigation with useful context' {
            $Groups = @(Get-TestDynamicGroup -Id 'candidate' -State 'Paused' `
                    -Licenses @([pscustomobject]@{ skuId = 'sku' }) `
                    -Rule '(user.displayName -match "^Admin")')
            $Policies = @(Get-TestCaPolicy -Id 'ca' -IncludeGroups @('candidate'))
            Mock -ModuleName Maester Invoke-MtGraphRequest { return $Groups }
            Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return $Policies }

            Test-MtDynamicGroupUserControlledAttributes | Should -BeTrue
            $script:Investigate | Should -BeTrue
            $script:TestResult | Should -Match 'Risky - user-influenceable attributes'
            $script:TestResult | Should -Match 'user\.displayName'
            $script:TestResult | Should -Match 'pattern or partial matching'
            $script:TestResult | Should -Match 'Include: \[Policy ca\] \(enabled\)'
            $script:TestResult | Should -Match 'Paused \| 1'
        }

        It 'separates risky and low-risk candidates into two tables' {
            $Rule = '(user.department -eq "Finance") -and ' +
                '(user.extensionAttribute4 -eq "Privileged")'
            $Groups = @(Get-TestDynamicGroup -Id 'candidate' `
                    -Rule $Rule)
            Mock -ModuleName Maester Invoke-MtGraphRequest { return $Groups }

            Test-MtDynamicGroupUserControlledAttributes | Should -BeTrue
            $script:Investigate | Should -BeTrue
            $script:TestResult | Should -Match 'Risky - user-influenceable attributes'
            $script:TestResult | Should -Match 'Low risk - application or administrator-controlled attributes'
            $script:TestResult | Should -Match 'user\.department'
            $script:TestResult | Should -Match 'user\.extensionAttribute4'
            ([regex]::Matches($script:TestResult, '\| Group \| Property \|').Count) |
                Should -Be 2
        }

        It 'skips when Graph is disconnected' {
            Mock -ModuleName Maester Test-MtConnection { return $false }

            Test-MtDynamicGroupUserControlledAttributes | Should -BeNull
            $script:SkippedBecause | Should -Be 'NotConnectedGraph'
        }
    }

    Context 'retiring memberOf rules' {
        BeforeEach {
            Mock -ModuleName Maester Get-Date {
                return [datetime]'2026-08-11T12:00:00Z'
            }
        }

        It 'passes when no memberOf rule is present' {
            $Groups = @(Get-TestDynamicGroup -Id 'safe' `
                    -Rule '(device.deviceOSType -eq "Windows")')
            Mock -ModuleName Maester Invoke-MtGraphRequest { return $Groups }

            Test-MtDynamicGroupMemberOfRule | Should -BeTrue
            $script:TestResult | Should -Match 'Well done'
            Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 `
                -ParameterFilter {
                $RelativeUri -eq 'groups' -and
                $Filter -eq "groupTypes/any(groupType:groupType eq 'DynamicMembership')" -and
                $QueryParameters['$count'] -eq 'true' -and
                @($Select).Count -eq 6 -and
                $Select -contains 'id' -and
                $Select -contains 'displayName' -and
                $Select -contains 'groupTypes' -and
                $Select -contains 'membershipRule' -and
                $Select -contains 'membershipRuleProcessingState' -and
                $Select -contains 'assignedLicenses'
            }
        }

        It 'fails before retirement and resolves source group context' {
            $SourceId = '00000000-0000-0000-0000-000000000001'
            $Target = Get-TestDynamicGroup -Id 'target' -State 'Paused' `
                -Licenses @([pscustomobject]@{ skuId = 'sku' }) `
                -Rule "user.memberOf -any (group.objectId -in ['$SourceId'])"
            $Source = [pscustomobject]@{ id = $SourceId; displayName = 'Source group' }
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($UniqueId) { return $Source }
                return @($Target)
            }

            Test-MtDynamicGroupMemberOfRule | Should -BeFalse
            $script:TestResult | Should -Match '84 days remaining'
            $script:TestResult | Should -Match '\[Source group\]'
            $script:TestResult | Should -Match 'Paused \| 1'
        }

        It 'fails on the retirement date and warns that membership may be stale' {
            $SourceId = '00000000-0000-0000-0000-000000000002'
            $Target = Get-TestDynamicGroup -Id 'target' `
                -Rule "device.memberOf -any (group.objectId -in ['$SourceId'])"
            Mock -ModuleName Maester Get-Date {
                return [datetime]'2026-11-03T00:00:00Z'
            }
            Mock -ModuleName Maester Invoke-MtGraphRequest { return @($Target) }

            Test-MtDynamicGroupMemberOfRule | Should -BeFalse
            $script:TestResult | Should -Match 'membership may already be stale'
        }

        It 'still fails when source group resolution is unavailable' {
            $SourceId = '00000000-0000-0000-0000-000000000003'
            $Target = Get-TestDynamicGroup -Id 'target' `
                -Rule "user.memberOf -any (group.objectId -in ['$SourceId'])"
            Mock -ModuleName Maester Invoke-MtGraphRequest {
                if ($UniqueId) { throw 'Unavailable' }
                return @($Target)
            }

            Test-MtDynamicGroupMemberOfRule | Should -BeFalse
            $script:TestResult | Should -Match "$SourceId`` \(unresolved\)"
        }

        It 'does not confuse transitiveMemberOf with the retiring operator' {
            $Groups = @(Get-TestDynamicGroup -Id 'safe' `
                    -Rule '(device.transitiveMemberOf -eq "group")')
            Mock -ModuleName Maester Invoke-MtGraphRequest { return $Groups }

            Test-MtDynamicGroupMemberOfRule | Should -BeTrue
        }
    }

    It 'skips both checks when the group query fails' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph failure' }

        Test-MtDynamicGroupUserControlledAttributes | Should -BeNull
        $script:SkippedBecause | Should -Be 'Error'
        Test-MtDynamicGroupMemberOfRule | Should -BeNull
        $script:SkippedBecause | Should -Be 'Error'
    }
}
