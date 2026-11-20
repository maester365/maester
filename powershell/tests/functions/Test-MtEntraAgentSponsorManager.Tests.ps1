BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtEntraAgentSponsorManager
}

Describe 'MT.1286: Test-MtEntraAgentSponsorManager' -Tag 'Unit' {
    BeforeAll {
        function Get-HttpError ([int]$StatusCode) {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $StatusCode.", $response)
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:SkippedCustomReason = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, $SkippedCustomReason, $SkippedError, $Severity)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:SkippedCustomReason = $SkippedCustomReason
        }

        # One object of each kind, all sponsored by the same user.
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'agent-1'; displayName = 'Invoice agent' }
        } -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'principal-1'; displayName = 'Invoice blueprint' }
        } -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentityBlueprintPrincipal' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'blueprint-1'; displayName = 'Invoice blueprint' }
        } -ParameterFilter { $RelativeUri -eq 'applications/microsoft.graph.agentIdentityBlueprint' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{
                '@odata.type'     = '#microsoft.graph.user'
                id                = 'sponsor-1'
                displayName       = 'Ada Sponsor'
                userPrincipalName = 'ada@contoso.com'
                accountEnabled    = $true
            }
        } -ParameterFilter { $RelativeUri -like '*/sponsors' }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'manager-1'; displayName = 'Grace Manager'; accountEnabled = $true }
        } -ParameterFilter { $RelativeUri -like 'users/*/manager' }
    }

    It 'passes when every user sponsor has an enabled manager, reading each manager once' {
        Test-MtEntraAgentSponsorManager | Should -BeTrue

        $script:TestResult | Should -Match 'All 3 user sponsorship'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter { $RelativeUri -eq 'users/sponsor-1/manager' }
    }

    It 'reports a user sponsor without a manager' {
        # Invoke-MtGraphRequest returns nothing when Graph answers 404, which is how a missing manager reads.
        Mock -ModuleName Maester Invoke-MtGraphRequest { } -ParameterFilter { $RelativeUri -like 'users/*/manager' }

        Test-MtEntraAgentSponsorManager | Should -BeFalse

        $script:TestResult | Should -Match 'Found 3 of 3 user sponsorship'
        # Get-MtSafeMarkdown escapes the parentheses and the @ of the sponsor column.
        $script:TestResult | Should -Match '\| Agent identity \| Invoice agent \| Ada Sponsor \\\(ada\\@contoso\.com\\\) \| No manager\. \|'
        $script:TestResult | Should -Match '\| Agent blueprint \| Invoice blueprint \|'
    }

    It 'reports a user sponsor whose manager is a disabled account' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ id = 'manager-1'; displayName = 'Grace Manager'; accountEnabled = $false }
        } -ParameterFilter { $RelativeUri -like 'users/*/manager' }

        Test-MtEntraAgentSponsorManager | Should -BeFalse

        $script:TestResult | Should -Match 'Manager Grace Manager is a disabled account\.'
    }

    It 'does not evaluate group sponsors, and skips when no object has a user sponsor' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ '@odata.type' = '#microsoft.graph.group'; id = 'group-1'; displayName = 'Agent sponsors' }
        } -ParameterFilter { $RelativeUri -like '*/sponsors' }

        Test-MtEntraAgentSponsorManager | Should -BeNullOrEmpty

        $script:SkippedBecause | Should -Be 'Custom'
        $script:SkippedCustomReason | Should -Match 'user sponsor'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 0 -ParameterFilter { $RelativeUri -like 'users/*/manager' }
    }

    It 'reports only the sponsor without a manager when another sponsor of the same object has one' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'sponsor-1'; displayName = 'Ada Sponsor'; userPrincipalName = 'ada@contoso.com'; accountEnabled = $true }
            [pscustomobject]@{ '@odata.type' = '#microsoft.graph.user'; id = 'sponsor-2'; displayName = 'Alan Sponsor'; userPrincipalName = 'alan@contoso.com'; accountEnabled = $true }
        } -ParameterFilter { $RelativeUri -like '*/sponsors' }
        Mock -ModuleName Maester Invoke-MtGraphRequest { } -ParameterFilter { $RelativeUri -eq 'users/sponsor-2/manager' }

        Test-MtEntraAgentSponsorManager | Should -BeFalse

        $script:TestResult | Should -Match 'Found 3 of 6 user sponsorship'
        $script:TestResult | Should -Not -Match 'Ada Sponsor'
        $script:TestResult | Should -Match 'Alan Sponsor'
    }

    It 'is skipped as not authorized when Graph answers 403' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 403) } -ParameterFilter { $RelativeUri -eq 'servicePrincipals/microsoft.graph.agentIdentity' }

        Test-MtEntraAgentSponsorManager | Should -BeNullOrEmpty

        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'is skipped with the error when a manager read fails for another reason' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-HttpError 500) } -ParameterFilter { $RelativeUri -like 'users/*/manager' }

        Test-MtEntraAgentSponsorManager | Should -BeNullOrEmpty

        $script:SkippedBecause | Should -Be 'Error'
    }
}
