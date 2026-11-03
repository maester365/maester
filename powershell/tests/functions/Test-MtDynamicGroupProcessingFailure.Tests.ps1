Describe 'Dynamic group processing failure check' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtDynamicGroupProcessingFailure

        function Get-TestDynamicGroup {
            param(
                [string] $Id,
                [string] $State = 'On',
                [string] $Rule = '(user.department -eq "Sales")'
            )

            return [pscustomobject]@{
                id                            = $Id
                displayName                   = "Group $Id"
                membershipRule                = $Rule
                membershipRuleProcessingState = $State
            }
        }

        function Get-TestProcessingStatus {
            param(
                [string] $Id,
                [string] $Status,
                [string] $ErrorMessage
            )

            return [pscustomobject]@{
                id                             = $Id
                membershipRuleProcessingStatus = [pscustomobject]@{
                    status       = $Status
                    errorMessage = $ErrorMessage
                }
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null

        Mock -ModuleName Maester Test-MtConnection { return $true }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @() }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
        }
    }

    It 'is not applicable when the tenant has no dynamic group' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { return @() }

        Test-MtDynamicGroupProcessingFailure | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotApplicable'
    }

    It 'skips when processing is paused for every dynamic group' {
        $Groups = @(Get-TestDynamicGroup -Id 'paused' -State 'Paused')
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($UniqueId) { throw 'A paused group has no status to read.' }
            return $Groups
        }

        Test-MtDynamicGroupProcessingFailure | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'Custom'
        $script:SkippedCustomReason | Should -Match 'paused for every dynamic group'
    }

    It 'passes when no active dynamic group has a failed status' {
        $Groups = @(
            Get-TestDynamicGroup -Id 'healthy'
            Get-TestDynamicGroup -Id 'running'
        )
        $Statuses = @(
            Get-TestProcessingStatus -Id 'healthy' -Status 'Succeeded'
            Get-TestProcessingStatus -Id 'running' -Status 'Running'
        )
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($UniqueId) { return $Statuses }
            return $Groups
        }

        Test-MtDynamicGroupProcessingFailure | Should -BeTrue
        $script:TestResult | Should -Match 'Well done'
        $script:TestResult | Should -Match 'None of the 2 dynamic group'
    }

    It 'fails and lists only the group whose processing failed, with its error message' {
        $Groups = @(
            Get-TestDynamicGroup -Id 'failed' -Rule 'user.propertyThatDoesNotExist -eq null'
            Get-TestDynamicGroup -Id 'healthy'
        )
        $Statuses = @(
            Get-TestProcessingStatus -Id 'failed' -Status 'Failed' `
                -ErrorMessage 'Membership updates could not be evaluated: unsupported property.'
            Get-TestProcessingStatus -Id 'healthy' -Status 'Succeeded'
        )
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($UniqueId) { return $Statuses }
            return $Groups
        }

        Test-MtDynamicGroupProcessingFailure | Should -BeFalse
        $script:TestResult | Should -Match 'Found 1 dynamic group'
        $script:TestResult | Should -Match '\[Group failed\]'
        $script:TestResult | Should -Match 'could not be evaluated: unsupported property'
        $script:TestResult | Should -Match 'user.propertyThatDoesNotExist -eq null'
        $script:TestResult | Should -Not -Match '\[Group healthy\]'
    }

    It 'reads the status of each active group from the beta Get group API, never of a paused one' {
        $Groups = @(
            Get-TestDynamicGroup -Id 'active-1'
            Get-TestDynamicGroup -Id 'active-2'
            Get-TestDynamicGroup -Id 'paused' -State 'Paused'
        )
        $Statuses = @(
            Get-TestProcessingStatus -Id 'active-1' -Status 'Succeeded'
            Get-TestProcessingStatus -Id 'active-2' -Status 'Succeeded'
        )
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($UniqueId) { return $Statuses }
            return $Groups
        }

        Test-MtDynamicGroupProcessingFailure | Should -BeTrue
        $script:TestResult | Should -Match '1 paused dynamic group'
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
            $RelativeUri -eq 'groups' -and
            $Filter -eq "groupTypes/any(groupType:groupType eq 'DynamicMembership')" -and
            $Select -contains 'membershipRuleProcessingState' -and
            -not $UniqueId
        }
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
            $RelativeUri -eq 'groups' -and
            $ApiVersion -eq 'beta' -and
            $Select -contains 'membershipRuleProcessingStatus' -and
            @($UniqueId).Count -eq 2 -and
            $UniqueId -contains 'active-1' -and
            $UniqueId -contains 'active-2' -and
            $UniqueId -notcontains 'paused'
        }
    }

    It 'shows the Conditional Access policies that reference a failed group' {
        $Groups = @(Get-TestDynamicGroup -Id 'failed')
        $Statuses = @(Get-TestProcessingStatus -Id 'failed' -Status 'Failed' -ErrorMessage 'Error')
        $Policy = [pscustomobject]@{
            id          = 'policy'
            displayName = 'Require MFA for Sales'
            state       = 'enabled'
            conditions  = [pscustomobject]@{
                users = [pscustomobject]@{
                    includeGroups = @('failed')
                    excludeGroups = @()
                }
            }
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { return @($Policy) }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($UniqueId) { return $Statuses }
            return $Groups
        }

        Test-MtDynamicGroupProcessingFailure | Should -BeFalse
        $script:TestResult | Should -Match 'Require MFA for Sales'
    }

    It 'still fails and lists the group when the Conditional Access policies cannot be read' {
        $Groups = @(Get-TestDynamicGroup -Id 'failed')
        $Statuses = @(Get-TestProcessingStatus -Id 'failed' -Status 'Failed' -ErrorMessage 'Error')
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            throw 'Insufficient privileges to complete the operation.'
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($UniqueId) { return $Statuses }
            return $Groups
        }

        Test-MtDynamicGroupProcessingFailure | Should -BeFalse
        $script:TestResult | Should -Match '\[Group failed\]'
        $script:TestResult | Should -Match 'Not available'
        $script:TestResult | Should -Match 'could not be read'
        $script:TestResult | Should -Match 'Insufficient privileges'
        $script:TestResult | Should -Not -Match 'None found'
    }

    It 'throws when the group query fails, which the engine records as an error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw 'Graph failure' }

        { Test-MtDynamicGroupProcessingFailure } | Should -Throw 'Graph failure'
        $row = @(Invoke-MtTest -Id 'MT.1265')[0]
        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'TestError'
    }
}
