Describe 'Conditional Access baseline scopes enforcement check' {
    BeforeAll {
        Import-Module $PSScriptRoot/../../Maester.psd1 -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name Test-MtCaBaselineScopesEnforcement

        # The error Invoke-MtGraphRequest rethrows when Graph answers with an HTTP error status.
        function Get-GraphHttpError {
            param([System.Net.HttpStatusCode] $StatusCode)
            $response = [System.Net.Http.HttpResponseMessage]::new($StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $([int]$StatusCode).", $response)
        }

        $script:EnforcedAppId = '00000002-0000-0000-c000-000000000000'
        $script:DisabledAppId = '00000000-0000-0000-0000-000000000000'
        $script:PlaceholderAppId = '7c9e6f2a-4b1d-4e8a-9f3c-b5d2a8e1c4f7'

        function Get-BaselineScopeSetting {
            param([string] $ResourceAppId)
            if (-not $ResourceAppId) {
                return [pscustomobject]@{ advancedSettings = $null }
            }
            [pscustomobject]@{
                advancedSettings = [pscustomobject]@{
                    baselineScopes = [pscustomobject]@{ resourceAppId = $ResourceAppId }
                }
            }
        }

        function Get-Policy {
            param(
                [string] $Name,
                [string[]] $ExcludeApplications = @(),
                [string[]] $IncludeApplications = @('All'),
                [string] $State = 'enabled'
            )
            [pscustomobject]@{
                id          = [guid]::NewGuid().Guid
                displayName = $Name
                state       = $State
                conditions  = [pscustomobject]@{
                    applications = [pscustomobject]@{
                        includeApplications = $IncludeApplications
                        excludeApplications = $ExcludeApplications
                    }
                }
            }
        }
    }

    BeforeEach {
        $script:Result = $null
        $script:Investigate = $false
        $script:GraphObjects = $null
        $script:GraphObjectType = $null
        $script:SkippedBecause = $null

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $GraphObjects, $GraphObjectType, [switch] $Investigate, $SkippedBecause)

            $script:Result = $Result
            $script:Investigate = [bool]$Investigate
            $script:GraphObjects = @($GraphObjects | Where-Object { $_ })
            $script:GraphObjectType = $GraphObjectType
            $script:SkippedBecause = $SkippedBecause
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } {
            [pscustomobject]@{ id = 'sp-object-id'; displayName = 'CA placeholder' }
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy { @() }
    }

    It 'passes when enforcement is enabled' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Result | Should -Match 'Well done'
        $script:Investigate | Should -BeFalse
    }

    It 'fails when enforcement is disabled and lists the All resources policies that have a resource exclusion' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:DisabledAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Require compliant device' -ExcludeApplications 'e3a1d7b9-6c2f-4d5e-a8b4-1f9c3e7d2a6b'
            Get-Policy -Name 'Require MFA'
            Get-Policy -Name 'Office 365 only' -IncludeApplications 'Office365' -ExcludeApplications 'e3a1d7b9-6c2f-4d5e-a8b4-1f9c3e7d2a6b'
            Get-Policy -Name 'Report-only pilot' -ExcludeApplications 'e3a1d7b9-6c2f-4d5e-a8b4-1f9c3e7d2a6b' -State 'enabledForReportingButNotEnforced'
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeFalse
        $script:Result | Should -Match 'explicitly \*\*disabled\*\*'
        $script:Result | Should -Match '%TestResult%'
        $script:Investigate | Should -BeFalse
        $script:GraphObjectType | Should -Be 'ConditionalAccess'
        $script:GraphObjects.displayName | Should -Be @('Require compliant device')
    }

    It 'fails when enforcement is disabled and says when no policy is affected today' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:DisabledAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Require MFA'
            Get-Policy -Name 'Office 365 only' -IncludeApplications 'Office365' -ExcludeApplications 'e3a1d7b9-6c2f-4d5e-a8b4-1f9c3e7d2a6b'
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeFalse
        $script:Result | Should -Match 'does not change any sign-in today'
        $script:Result | Should -Not -Match '%TestResult%'
        $script:GraphObjects | Should -BeNullOrEmpty
    }

    It 'asks for investigation when no choice is stored because <Case>' -ForEach @(
        @{ Case = 'advancedSettings is null'; Settings = { [pscustomobject]@{ advancedSettings = $null } } }
        @{ Case = 'baselineScopes is null'; Settings = { [pscustomobject]@{ advancedSettings = [pscustomobject]@{ baselineScopes = $null } } } }
        @{ Case = 'the response has no advancedSettings'; Settings = { [pscustomobject]@{} } }
    ) {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } { & $Settings }.GetNewClosure()

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:Result | Should -Match 'staged rollout'
    }

    It 'asks for investigation and lists the policies that exclude the placeholder application' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:PlaceholderAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Require compliant device' -ExcludeApplications $script:PlaceholderAppId, 'e3a1d7b9-6c2f-4d5e-a8b4-1f9c3e7d2a6b'
            Get-Policy -Name 'Require MFA'
            Get-Policy -Name 'Report-only pilot' -ExcludeApplications $script:PlaceholderAppId -State 'enabledForReportingButNotEnforced'
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:Result | Should -Match 'Customize behavior'
        $script:Result | Should -Match 'still needs the legacy behavior'
        $script:Result | Should -Match '%TestResult%'
        $script:GraphObjectType | Should -Be 'ConditionalAccess'
        $script:GraphObjects.displayName | Should -Be @('Require compliant device')
    }

    It 'does not list a policy that excludes the placeholder application but does not target All resources' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:PlaceholderAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Office 365 only' -IncludeApplications 'Office365' -ExcludeApplications $script:PlaceholderAppId
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:Result | Should -Match 'no effect'
        $script:GraphObjects | Should -BeNullOrEmpty
    }

    It 'asks for investigation when no enabled policy excludes the placeholder application' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:PlaceholderAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Require MFA' -ExcludeApplications 'e3a1d7b9-6c2f-4d5e-a8b4-1f9c3e7d2a6b'
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:Result | Should -Match 'no effect'
    }

    It 'links the placeholder application, or names its ID when no service principal is found' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:PlaceholderAppId
        }

        $null = Test-MtCaBaselineScopesEnforcement
        $script:Result | Should -Match '\[CA placeholder\]\(https://entra\.microsoft\.com/'

        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } { $null }
        $null = Test-MtCaBaselineScopesEnforcement
        $script:Result | Should -Match ([regex]::Escape($script:PlaceholderAppId))
        $script:Result | Should -Match 'no service principal found'
    }

    It 'fails when an enabled policy excludes Windows Azure Active Directory, whatever the selection is (<Selection>)' -ForEach @(
        @{ Selection = 'enabled'; AppId = '00000002-0000-0000-c000-000000000000' }
        @{ Selection = 'customized'; AppId = '7c9e6f2a-4b1d-4e8a-9f3c-b5d2a8e1c4f7' }
        @{ Selection = 'disabled'; AppId = '00000000-0000-0000-0000-000000000000' }
        @{ Selection = 'no choice'; AppId = '' }
    ) {
        $settings = Get-BaselineScopeSetting -ResourceAppId $AppId
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } { $settings }.GetNewClosure()
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Require compliant device' -ExcludeApplications $script:EnforcedAppId
            Get-Policy -Name 'Require MFA'
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeFalse
        $script:Investigate | Should -BeFalse
        $script:Result | Should -Match 'obtain a directory token'
        $script:GraphObjectType | Should -Be 'ConditionalAccess'
        $script:GraphObjects.displayName | Should -Be @('Require compliant device')
    }

    It 'fails when a policy that includes Windows Azure Active Directory itself also excludes it' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Directory access' -IncludeApplications $script:EnforcedAppId -ExcludeApplications $script:EnforcedAppId
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeFalse
        $script:GraphObjects.displayName | Should -Be @('Directory access')
    }

    It 'asks for investigation when a policy that does not include Windows Azure Active Directory excludes it' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Office 365 only' -IncludeApplications 'Office365' -ExcludeApplications $script:EnforcedAppId
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:Result | Should -Not -Match 'Well done'
        $script:Result | Should -Match 'no effect today'
        $script:Result | Should -Match '\[Office 365 only\]\('
        $script:GraphObjects | Should -BeNullOrEmpty
    }

    It 'adds the policies with an inactive Windows Azure Active Directory exclusion to the <Selection> result' -ForEach @(
        @{ Selection = 'disabled'; AppId = '00000000-0000-0000-0000-000000000000'; Ret = $false; Inv = $false }
        @{ Selection = 'customized'; AppId = '7c9e6f2a-4b1d-4e8a-9f3c-b5d2a8e1c4f7'; Ret = $true; Inv = $true }
        @{ Selection = 'no choice'; AppId = ''; Ret = $true; Inv = $true }
    ) {
        $settings = Get-BaselineScopeSetting -ResourceAppId $AppId
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } { $settings }.GetNewClosure()
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Office 365 only' -IncludeApplications 'Office365' -ExcludeApplications $script:EnforcedAppId
        }

        Test-MtCaBaselineScopesEnforcement | Should -Be $Ret
        $script:Investigate | Should -Be $Inv
        $script:Result | Should -Match 'no effect today'
        $script:Result | Should -Match '\[Office 365 only\]\('
    }

    It 'lists both kinds of Windows Azure Active Directory exclusion when the tenant has both' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Require compliant device' -ExcludeApplications $script:EnforcedAppId
            Get-Policy -Name 'Office 365 only' -IncludeApplications 'Office365' -ExcludeApplications $script:EnforcedAppId
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeFalse
        $script:GraphObjects.displayName | Should -Be @('Require compliant device')
        $script:Result | Should -Match 'no effect today'
        $script:Result | Should -Match '\[Office 365 only\]\('
    }

    It 'is skipped when the Conditional Access settings return <Code>' -ForEach @(
        @{ Code = 401; Status = [System.Net.HttpStatusCode]::Unauthorized }
        @{ Code = 403; Status = [System.Net.HttpStatusCode]::Forbidden }
    ) {
        $err = Get-GraphHttpError -StatusCode $Status
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } { throw $err }.GetNewClosure()

        Test-MtCaBaselineScopesEnforcement | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
        Should -Invoke -ModuleName Maester Get-MtConditionalAccessPolicy -Times 0
    }

    It 'rethrows other errors from the Conditional Access settings' {
        $err = Get-GraphHttpError -StatusCode ([System.Net.HttpStatusCode]::InternalServerError)
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } { throw $err }.GetNewClosure()

        { Test-MtCaBaselineScopesEnforcement } | Should -Throw '*500*'
        $script:SkippedBecause | Should -BeNullOrEmpty
    }

    It 'falls back to the application ID when the placeholder lookup returns 403' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:PlaceholderAppId
        }
        $err = Get-GraphHttpError -StatusCode ([System.Net.HttpStatusCode]::Forbidden)
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } { throw $err }.GetNewClosure()

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:Result | Should -Match ([regex]::Escape($script:PlaceholderAppId))
        $script:Result | Should -Match 'no permission to read it'
    }

    It 'rethrows other errors from the placeholder lookup' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:PlaceholderAppId
        }
        $err = Get-GraphHttpError -StatusCode ([System.Net.HttpStatusCode]::BadGateway)
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } { throw $err }.GetNewClosure()

        { Test-MtCaBaselineScopesEnforcement } | Should -Throw '*502*'
    }

    It 'ignores policies that are not enabled or have no application conditions' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Disabled policy' -ExcludeApplications $script:EnforcedAppId -State 'disabled'
            [pscustomobject]@{ id = 'p-null'; displayName = 'No application conditions'; state = 'enabled'; conditions = [pscustomobject]@{ applications = $null } }
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Result | Should -Match 'Well done'
    }

    It 'compares application IDs without regard to case' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId.ToUpperInvariant()
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Result | Should -Match 'Well done'
    }

    It 'ignores a report-only policy that excludes Windows Azure Active Directory' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }
        Mock -ModuleName Maester Get-MtConditionalAccessPolicy {
            Get-Policy -Name 'Report-only pilot' -ExcludeApplications $script:EnforcedAppId -State 'enabledForReportingButNotEnforced'
        }

        Test-MtCaBaselineScopesEnforcement | Should -BeTrue
        $script:Result | Should -Match 'Well done'
    }

    It 'reads the selection from the beta Conditional Access settings' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'identity/conditionalAccess/settings' } {
            Get-BaselineScopeSetting -ResourceAppId $script:EnforcedAppId
        }

        $null = Test-MtCaBaselineScopesEnforcement

        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Exactly -Times 1 -ParameterFilter {
            $ApiVersion -eq 'beta' -and $RelativeUri -eq 'identity/conditionalAccess/settings'
        }
    }
}
