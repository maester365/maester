BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtEntraUserConsentGrant
}

Describe 'MT.1287: Test-MtEntraUserConsentGrant' -Tag 'Unit' {
    BeforeAll {
        # Graph errors name the status, not its number: "Response status code does not indicate success: Forbidden (Forbidden)."
        function Get-HttpError ([int]$StatusCode) {
            $response = [System.Net.Http.HttpResponseMessage]::new([System.Net.HttpStatusCode]$StatusCode)
            [Microsoft.PowerShell.Commands.HttpResponseException]::new("Response status code does not indicate success: $([System.Net.HttpStatusCode]$StatusCode) ($($response.ReasonPhrase)).", $response)
        }

        function Get-TestServicePrincipal {
            param(
                [string] $Id,
                [string] $DisplayName,
                [string] $OwnerTenantId = 'third-party-tenant',
                [string] $Publisher,
                [bool] $AccountEnabled = $true
            )
            [pscustomobject]@{
                id                     = $Id
                appId                  = "app-$Id"
                displayName            = $DisplayName
                appOwnerOrganizationId = $OwnerTenantId
                verifiedPublisher      = [pscustomobject]@{ displayName = $Publisher }
                accountEnabled         = $AccountEnabled
            }
        }

        function Get-TestGrant {
            param(
                [string] $ClientId,
                [string] $PrincipalId,
                [string] $ResourceId = 'graph',
                [string] $Scope = 'User.Read'
            )
            [pscustomobject]@{
                id          = "$ClientId-$PrincipalId-$ResourceId"
                clientId    = $ClientId
                principalId = $PrincipalId
                resourceId  = $ResourceId
                scope       = $Scope
            }
        }
    }

    BeforeEach {
        $script:TestResult = $null
        $script:SkippedBecause = $null
        $script:Investigate = $false
        # Policy IDs without the ManagePermissionGrantsForSelf prefix. None means user consent is turned off.
        $script:ConsentPolicies = @()
        $script:Grants = @()
        $script:ServicePrincipals = @(
            Get-TestServicePrincipal -Id 'graph' -DisplayName 'Microsoft Graph' -OwnerTenantId 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
            Get-TestServicePrincipal -Id 'exo' -DisplayName 'Office 365 Exchange Online' -OwnerTenantId 'f8cdef31-a31e-4b4a-93e4-5f571e91255a'
        )

        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result, $SkippedBecause, [switch]$Investigate)

            $script:TestResult = $Result
            $script:SkippedBecause = $SkippedBecause
            $script:Investigate = $Investigate.IsPresent
        }

        Mock -ModuleName Maester Get-MgContext { [pscustomobject]@{ TenantId = 'own-tenant' } }

        # A group owner consent policy is always there: it must not count as user consent.
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'policies/authorizationPolicy' } {
            $Assigned = @($script:ConsentPolicies | ForEach-Object { "ManagePermissionGrantsForSelf.$_" })
            $Assigned += 'ManagePermissionGrantsForOwnedResource.microsoft-dynamically-managed-permissions-for-team'
            [pscustomobject]@{ defaultUserRolePermissions = [pscustomobject]@{ permissionGrantPoliciesAssigned = $Assigned } }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' } { $script:Grants }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } {
            $script:ServicePrincipals | Where-Object { $_.id -in $UniqueId }
        }
    }

    It 'is skipped as not applicable when users can consent to any app' {
        $script:ConsentPolicies = @('microsoft-user-default-legacy')

        Test-MtEntraUserConsentGrant | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotApplicable'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' }
    }

    It 'passes when user consent is turned off and no user grant remains' {
        Test-MtEntraUserConsentGrant | Should -BeTrue
        $script:TestResult | Should -BeLike 'Well done.*'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Times 0 -Exactly -ParameterFilter { $RelativeUri -eq 'servicePrincipals' }
    }

    It 'fails when user consent is turned off and a third-party app keeps user grants' {
        $script:ServicePrincipals += Get-TestServicePrincipal -Id 'crm' -DisplayName 'Contoso CRM' -Publisher 'Contoso Ltd'
        $script:Grants = @(
            Get-TestGrant -ClientId 'crm' -PrincipalId 'user-1' -Scope 'User.Read Mail.Read'
            Get-TestGrant -ClientId 'crm' -PrincipalId 'user-2' -Scope ' offline_access User.Read '
            Get-TestGrant -ClientId 'crm' -PrincipalId 'user-2' -ResourceId 'exo' -Scope 'EWS.AccessAsUser.All'
        )

        Test-MtEntraUserConsentGrant | Should -BeFalse
        $script:Investigate | Should -BeFalse
        $script:TestResult | Should -BeLike 'User consent is turned off, but 1 third-party app(s) still hold delegated permissions that 2 user(s)*'
        $script:TestResult | Should -Match ([regex]::Escape('[Contoso CRM](') + '[^)]*/Permissions/objectId/crm/appId/app-crm\)')
        $script:TestResult | Should -Match ([regex]::Escape(
                '| Contoso Ltd | 2 | Microsoft Graph\: Mail.Read, offline\_access, User.Read; Office 365 Exchange Online\: EWS.AccessAsUser.All |'
            ))
    }

    It 'passes when only Microsoft apps, apps of this tenant and disabled apps keep user grants' {
        $script:ServicePrincipals += @(
            Get-TestServicePrincipal -Id 'msapp' -DisplayName 'Microsoft app' -OwnerTenantId '72f988bf-86f1-41af-91ab-2d7cd011db47'
            Get-TestServicePrincipal -Id 'inhouse' -DisplayName 'In-house app' -OwnerTenantId 'own-tenant'
            Get-TestServicePrincipal -Id 'retired' -DisplayName 'Retired app' -AccountEnabled $false
        )
        $script:Grants = @(
            Get-TestGrant -ClientId 'msapp' -PrincipalId 'user-1'
            Get-TestGrant -ClientId 'inhouse' -PrincipalId 'user-1'
            Get-TestGrant -ClientId 'retired' -PrincipalId 'user-2'
        )

        Test-MtEntraUserConsentGrant | Should -BeTrue
        $script:TestResult | Should -BeLike 'Well done.*'
    }

    It 'asks for a review when user consent is limited and a third-party app keeps user grants' {
        $script:ConsentPolicies = @('microsoft-user-default-low')
        $script:ServicePrincipals += Get-TestServicePrincipal -Id 'notes' -DisplayName 'Notes app'
        $script:Grants = @(Get-TestGrant -ClientId 'notes' -PrincipalId 'user-1' -Scope 'Files.Read')

        Test-MtEntraUserConsentGrant | Should -BeTrue
        $script:Investigate | Should -BeTrue
        $script:TestResult | Should -BeLike 'User consent is limited by*microsoft-user-default-low*1 third-party app(s)*'
        $script:TestResult | Should -Match ([regex]::Escape('| None | 1 | Microsoft Graph\: Files.Read |'))
    }

    It 'is skipped as not authorized when Graph answers 403' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'oauth2PermissionGrants' } { throw (Get-HttpError 403) }

        Test-MtEntraUserConsentGrant | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'is skipped as not authorized when a batched lookup answers 403' {
        $script:ServicePrincipals += Get-TestServicePrincipal -Id 'crm' -DisplayName 'Contoso CRM'
        $script:Grants = @(Get-TestGrant -ClientId 'crm' -PrincipalId 'user-1')
        # The shape Invoke-MtGraphRequest throws for a failed request inside a batch.
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("Graph batch request for 'servicePrincipals/crm' failed with status 403"),
                'MtGraphBatchRequestFailed', [System.Management.Automation.ErrorCategory]::PermissionDenied, 'servicePrincipals/crm')
        }

        Test-MtEntraUserConsentGrant | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotAuthorized'
    }

    It 'lets other batch errors reach the engine' {
        $script:ServicePrincipals += Get-TestServicePrincipal -Id 'crm' -DisplayName 'Contoso CRM'
        $script:Grants = @(Get-TestGrant -ClientId 'crm' -PrincipalId 'user-1')
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } {
            throw [System.Management.Automation.ErrorRecord]::new(
                [System.InvalidOperationException]::new("Graph batch request for 'servicePrincipals/crm' failed with status 500"),
                'MtGraphBatchRequestFailed', [System.Management.Automation.ErrorCategory]::InvalidResult, 'servicePrincipals/crm')
        }

        { Test-MtEntraUserConsentGrant } | Should -Throw -ExpectedMessage '*status 500*'
    }

    It 'lets other Graph errors reach the engine' {
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'policies/authorizationPolicy' } { throw (Get-HttpError 500) }

        { Test-MtEntraUserConsentGrant } | Should -Throw -ExpectedMessage '*InternalServerError*'
    }
}
