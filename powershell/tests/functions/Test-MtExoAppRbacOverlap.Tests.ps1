BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtExoAppRbacOverlap

    # ExchangeOnlineManagement is optional; provide a stub so Get-ManagementRoleAssignment can be mocked when it is not installed.
    if (-not (Get-Command Get-ManagementRoleAssignment -ErrorAction SilentlyContinue)) {
        function global:Get-ManagementRoleAssignment {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSReviewUnusedParameter', 'RoleAssigneeType', Justification = 'Stub signature only; Mock binds -RoleAssigneeType from it.')]
            param($RoleAssigneeType)
        }
        $script:removeExoStub = $true
    }
    if (-not (Get-Command Get-ApplicationAccessPolicy -ErrorAction SilentlyContinue)) {
        function global:Get-ApplicationAccessPolicy { param() }
        $script:removeAapStub = $true
    }

    $script:GraphSpId = 'graph-sp-id'
    $script:MailReadId = '810c84a8-4a9e-49e6-bf7d-12d183f40d01'
    $script:MailSendId = 'b633e1c5-b582-4048-a93e-9f11b44c7e96'
    $script:MailReadWriteId = 'e2a3a72e-5f79-4c64-b1b1-878b674786c9'
    $script:MailboxItemReadId = 'mailboxitem-read-all-id'
    $script:MailReadBasicAllId = '693c5e45-0940-467d-9b8a-1022fb9d42ef'
}

AfterAll {
    if ($script:removeExoStub) {
        Remove-Item -Path Function:\Get-ManagementRoleAssignment -ErrorAction SilentlyContinue
    }
    if ($script:removeAapStub) {
        Remove-Item -Path Function:\Get-ApplicationAccessPolicy -ErrorAction SilentlyContinue
    }
}

Describe 'Test-MtExoAppRbacOverlap' {
    BeforeEach {
        $script:Result = $null
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result)
            $script:Result = $Result
        }
        Mock -ModuleName Maester Get-MtLinkServicePrincipal { 'app-link' }
        Mock -ModuleName Maester Get-ApplicationAccessPolicy { @() }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals' } {
            [PSCustomObject]@{
                id       = $script:GraphSpId
                appRoles = @(
                    [PSCustomObject]@{ id = $script:MailReadId; value = 'Mail.Read' }
                    [PSCustomObject]@{ id = $script:MailSendId; value = 'Mail.Send' }
                    [PSCustomObject]@{ id = $script:MailReadWriteId; value = 'Mail.ReadWrite' }
                    [PSCustomObject]@{ id = $script:MailboxItemReadId; value = 'MailboxItem.Read.All' }
                    [PSCustomObject]@{ id = $script:MailReadBasicAllId; value = 'Mail.ReadBasic.All' }
                )
            }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1' } {
            [PSCustomObject]@{ id = 'app-1'; displayName = 'Contoso Mail App'; appId = 'appid-1' }
        }
    }

    It 'Passes when no app has an Exchange RBAC assignment' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment { @() }

        Test-MtExoAppRbacOverlap | Should -BeTrue
        Should -Invoke -ModuleName Maester Invoke-MtGraphRequest -Times 0
    }

    It 'Fails when an app has the same permission scoped in Exchange and tenant-wide in Entra' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| app-link | appid-1 | Mail.Read | Mail.Read | Sales mailboxes |*'
    }

    It 'Fails when the tenant-wide grant is a broader permission that includes the scoped one' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadWriteId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| app-link | appid-1 | Mail.Read | Mail.ReadWrite | Sales mailboxes |*'
    }

    It 'Fails when the tenant-wide grant is Mail.ReadBasic.All and the scoped role is Mail.ReadBasic' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.ReadBasic'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadBasicAllId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| app-link | appid-1 | Mail.ReadBasic | Mail.ReadBasic.All | Sales mailboxes |*'
    }

    It 'Passes when the Exchange assignment has no resource scope' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeTrue
    }

    It 'Passes when the tenant-wide grant is a different permission' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailSendId }
        }

        Test-MtExoAppRbacOverlap | Should -BeTrue
    }

    It 'Ignores a matching grant on a resource other than Microsoft Graph' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = 'other-api'; appRoleId = $script:MailReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeTrue
    }

    It 'Ignores Exchange roles with no Graph twin and disabled assignments' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application EWS.AccessAsApp'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $false; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeTrue
    }

    It 'Shows the administrative unit when the assignment is scoped to one' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Send'; Enabled = $true; RecipientAdministrativeUnitScope = 'Europe AU' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailSendId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| Mail.Send | Europe AU |*'
    }

    It 'Maps Application Exchange Full Access to the Graph permissions it covers' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Exchange Full Access'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadWriteId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| Mail.ReadWrite | Sales mailboxes |*'
    }

    It 'Maps roles whose Graph permission ends in .All' {
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application MailboxItem.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailboxItemReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| MailboxItem.Read.All | Sales mailboxes |*'
    }

    It 'Lists an app restricted by an Application Access Policy for review instead of failing' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [PSCustomObject]@{ AppId = 'appid-1'; AccessRight = 'RestrictAccess' }
        }
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeTrue
        $script:Result | Should -BeLike '*Application Access Policy limits that grant*'
        $script:Result | Should -BeLike '*| app-link | appid-1 | Mail.Read | Mail.Read | Sales mailboxes |*'
    }

    It 'Still fails when the policy cannot restrict the tenant-wide permission' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [PSCustomObject]@{ AppId = 'appid-1'; AccessRight = 'RestrictAccess' }
        }
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application MailboxItem.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailboxItemReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
        $script:Result | Should -BeLike '*| app-link | appid-1 | MailboxItem.Read.All | MailboxItem.Read.All | Sales mailboxes |*'
    }

    It 'Still fails when the app only has a DenyAccess policy' {
        Mock -ModuleName Maester Get-ApplicationAccessPolicy {
            [PSCustomObject]@{ AppId = 'appid-1'; AccessRight = 'DenyAccess' }
        }
        Mock -ModuleName Maester Get-ManagementRoleAssignment {
            [PSCustomObject]@{ App = 'app-1'; Role = 'Application Mail.Read'; Enabled = $true; CustomResourceScope = 'Sales mailboxes' }
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest -ParameterFilter { $RelativeUri -eq 'servicePrincipals/app-1/appRoleAssignments' } {
            [PSCustomObject]@{ resourceId = $script:GraphSpId; appRoleId = $script:MailReadId }
        }

        Test-MtExoAppRbacOverlap | Should -BeFalse
    }
}
