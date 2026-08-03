Describe 'Test-MtPimAlertsExists' {
    BeforeAll {
        function New-PimAlert {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper creates an in-memory fixture and has no external side effects.')]
            param(
                [string] $AlertId = 'RedundantAssignmentAlert',
                [bool] $IsActive = $true,
                [object[]] $AlertIncidents = @()
            )

            return [PSCustomObject]@{
                id                 = "DirectoryRole_tenant-id_$AlertId"
                alertDefinitionId  = "DirectoryRole_tenant-id_$AlertId"
                isActive           = $IsActive
                incidentCount      = $AlertIncidents.Count
                alertDefinition    = [PSCustomObject]@{
                    displayName    = 'PIM alert name'
                    description    = 'PIM alert description'
                    securityImpact = 'PIM security impact'
                    mitigationSteps = 'PIM mitigation steps'
                    howToPrevent   = 'PIM prevention guidance'
                }
                alertConfiguration = [PSCustomObject]@{
                    isEnabled = $true
                }
                alertIncidents     = $AlertIncidents
            }
        }

        function New-PimAlertIncident {
            [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '', Justification = 'Test helper creates an in-memory fixture and has no external side effects.')]
            param(
                [string] $AssigneeId,
                [string] $AssigneeDisplayName,
                [string] $AssigneeUserPrincipalName,
                [string] $RoleTemplateId = 'control-plane-role',
                [string] $RoleDisplayName = 'Global Administrator'
            )

            return [PSCustomObject]@{
                id                        = "assignment-$AssigneeId"
                assigneeId                = $AssigneeId
                assigneeDisplayName       = $AssigneeDisplayName
                assigneeUserPrincipalName = $AssigneeUserPrincipalName
                roleTemplateId            = $RoleTemplateId
                roleDisplayName           = $RoleDisplayName
            }
        }
    }

    BeforeEach {
        $script:testDescription = $null
        $script:testResult = $null
        $script:skippedBecause = $null

        Mock -ModuleName Maester Get-MgContext {
            return [PSCustomObject]@{ TenantId = 'tenant-id' }
        }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Description, $Result, $SkippedBecause)

            $script:testDescription = $Description
            $script:testResult = $Result
            $script:skippedBecause = $SkippedBecause
        }
    }

    It 'queries the PIM v3 alert endpoint and preserves the existing result contract' {
        $incident = New-PimAlertIncident -AssigneeId 'user-1' -AssigneeDisplayName 'User One' -AssigneeUserPrincipalName 'user1@contoso.com'
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return New-PimAlert -AlertIncidents @($incident)
        }

        $result = Test-MtPimAlertsExists -AlertId RedundantAssignmentAlert -FilteredBreakGlass @()

        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter {
            $ApiVersion -eq 'beta' -and
            $RelativeUri -eq 'identityGovernance/roleManagementAlerts/alerts/DirectoryRole_tenant-id_RedundantAssignmentAlert?$expand=alertDefinition,alertConfiguration,alertIncidents'
        }
        $result.isActive | Should -BeTrue
        $result.numberOfAffectedItems | Should -Be 1
        $result.alertName | Should -Be 'PIM alert name'
        $result.alertDescription | Should -Be 'PIM alert description'
        $result.securityImpact | Should -Be 'PIM security impact'
        $result.mitigationSteps | Should -Be 'PIM mitigation steps'
        $result.howToPrevent | Should -Be 'PIM prevention guidance'
        $script:testDescription | Should -Match 'PIM security impact'
        $script:testResult | Should -Match 'User One with Global Administrator by AssigneeId user-1'
    }

    It 'returns zero affected items for an inactive alert' {
        $incident = New-PimAlertIncident -AssigneeId 'user-1' -AssigneeDisplayName 'User One' -AssigneeUserPrincipalName 'user1@contoso.com'
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return New-PimAlert -IsActive $false -AlertIncidents @($incident)
        }

        $result = Test-MtPimAlertsExists -AlertId RedundantAssignmentAlert -FilteredBreakGlass @()

        $result.numberOfAffectedItems | Should -Be 0
        $script:testResult | Should -Be 'All privileged role assignments are managed by PIM. Well done!'
    }

    It 'filters incidents by Enterprise Access Model role classification' {
        $controlPlaneIncident = New-PimAlertIncident -AssigneeId 'user-1' -AssigneeDisplayName 'Control User' -AssigneeUserPrincipalName 'control@contoso.com' -RoleTemplateId 'control-plane-role'
        $managementPlaneIncident = New-PimAlertIncident -AssigneeId 'user-2' -AssigneeDisplayName 'Management User' -AssigneeUserPrincipalName 'management@contoso.com' -RoleTemplateId 'management-plane-role'
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return New-PimAlert -AlertIncidents @($controlPlaneIncident, $managementPlaneIncident)
        }
        Mock -ModuleName Maester Invoke-WebRequest {
            return '[{"RoleId":"control-plane-role","Classification":{"EAMTierLevelName":"ControlPlane"}},{"RoleId":"management-plane-role","Classification":{"EAMTierLevelName":"ManagementPlane"}}]'
        }

        $result = Test-MtPimAlertsExists -AlertId RedundantAssignmentAlert -FilteredAccessLevel ControlPlane -FilteredBreakGlass @()

        $result.numberOfAffectedItems | Should -Be 1
        $script:testResult | Should -Match 'Control User'
        $script:testResult | Should -Not -Match 'Management User'
    }

    It 'excludes break-glass accounts and updates the affected item count' {
        $breakGlassIncident = New-PimAlertIncident -AssigneeId 'break-glass-user' -AssigneeDisplayName 'Emergency Admin' -AssigneeUserPrincipalName 'emergency@contoso.com'
        $regularIncident = New-PimAlertIncident -AssigneeId 'regular-user' -AssigneeDisplayName 'Regular Admin' -AssigneeUserPrincipalName 'regular@contoso.com'
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            return New-PimAlert -AlertIncidents @($breakGlassIncident, $regularIncident)
        }

        $result = Test-MtPimAlertsExists -AlertId RedundantAssignmentAlert -FilteredBreakGlass @([PSCustomObject]@{ Id = 'break-glass-user' })

        $result.numberOfAffectedItems | Should -Be 1
        $script:testResult | Should -Match 'Regular Admin'
        $script:testResult | Should -Not -Match 'Emergency Admin'
    }

    It 'skips the test when the PIM v3 request fails' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw 'PIM v3 is unavailable'
        }

        $result = Test-MtPimAlertsExists -AlertId RedundantAssignmentAlert -FilteredBreakGlass @()

        $result | Should -BeNullOrEmpty
        $script:skippedBecause | Should -Be 'Error'
    }
}
