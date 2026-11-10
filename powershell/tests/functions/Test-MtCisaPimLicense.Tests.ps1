BeforeAll {
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name @(
        'Test-MtCisaPermanentRoleAssignment',
        'Test-MtCisaUnmanagedRoleAssignment',
        'Test-MtCisaRequireActivationApproval',
        'Test-MtCisaAssignmentNotification',
        'Test-MtCheckCISAMSAAD78',
        'Test-MtCheckCISAMSAAD79'
    )

    function Get-TestPimErrorRecord {
        param([string] $Code)

        $record = [System.Management.Automation.ErrorRecord]::new(
            [System.Exception]::new('Response status code does not indicate success: 400 (Bad Request).'),
            'InvokeGraphHttpResponseException',
            [System.Management.Automation.ErrorCategory]::InvalidOperation,
            $null
        )
        $record.ErrorDetails = [System.Management.Automation.ErrorDetails]::new(
            "{`"error`":{`"code`":`"$Code`",`"message`":`"PIM request rejected.`"}}"
        )
        return $record
    }
}

Describe 'CISA PIM API licence rejection: <CheckName>' -ForEach @(
    @{ CheckName = 'Test-MtCisaPermanentRoleAssignment' }
    @{ CheckName = 'Test-MtCisaUnmanagedRoleAssignment' }
    @{ CheckName = 'Test-MtCisaRequireActivationApproval' }
    @{ CheckName = 'Test-MtCisaAssignmentNotification' }
    @{ CheckName = 'Test-MtCheckCISAMSAAD78' }
    @{ CheckName = 'Test-MtCheckCISAMSAAD79' }
) {
    BeforeEach {
        $script:SkippedBecause = $null
        $script:Compliant = $true
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Get-MtRole {
            @(
                [pscustomobject]@{ id = '62e90394-69f5-4237-9190-012177145e10'; displayName = 'Global Administrator' }
                [pscustomobject]@{ id = '194ae4cb-b126-40b2-bd5b-6091b380977d'; displayName = 'Security Administrator' }
            )
        }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($SkippedBecause)
            $script:SkippedBecause = $SkippedBecause
        }
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            if ($RelativeUri -eq 'roleManagement/directory/roleAssignmentSchedules') {
                return [pscustomobject]@{
                    createdUsing = if ($script:Compliant) { 'request-1' } else { $null }
                    scheduleInfo = @{
                        startDateTime = if ($script:Compliant) { '2026-01-01T00:00:00Z' } else { $null }
                        expiration = @{ type = if ($script:Compliant) { 'afterDateTime' } else { 'noExpiration' } }
                    }
                    principal = [pscustomobject]@{
                        id = 'user-1'
                        displayName = 'Test user'
                        '@odata.type' = '#microsoft.graph.user'
                    }
                }
            }
            return [pscustomobject]@{
                policy = @{
                    rules = @(
                        [pscustomobject]@{
                            '@odata.type' = '#microsoft.graph.unifiedRoleManagementPolicyApprovalRule'
                            setting = @{ isApprovalRequired = $script:Compliant }
                        }
                        foreach ($id in @(
                            'Notification_Admin_Admin_Eligibility',
                            'Notification_Admin_Admin_Assignment',
                            'Notification_Admin_EndUser_Assignment'
                        )) {
                            [pscustomobject]@{
                                id = $id
                                notificationRecipients = if ($script:Compliant) { @('monitor@example.com') } else { @() }
                            }
                        }
                    )
                }
            }
        }
    }

    It 'skips instead of returning a verdict when the API rejects the licence' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-TestPimErrorRecord -Code 'AadPremiumLicenseRequired')
        }

        & $CheckName | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotLicensedEntraIDP2OrGovernance'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1
    }

    It 'requests terminating API errors before interpreting PIM data' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            param($ErrorAction)

            Write-Error -ErrorRecord (Get-TestPimErrorRecord -Code 'AadPremiumLicenseRequired') -ErrorAction $ErrorAction
        }

        & $CheckName | Should -BeNullOrEmpty
        $script:SkippedBecause | Should -Be 'NotLicensedEntraIDP2OrGovernance'
        Should -Invoke Invoke-MtGraphRequest -ModuleName Maester -Exactly 1 -ParameterFilter { $ErrorAction -eq 'Stop' }
    }

    It 'propagates <Code> instead of treating it as a licence skip' -ForEach @(
        @{ Code = 'Authorization_RequestDenied' }
        @{ Code = 'InternalServerError' }
    ) {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-TestPimErrorRecord -Code $Code)
        }

        { & $CheckName } | Should -Throw -ErrorId 'InvokeGraphHttpResponseException'
        $script:SkippedBecause | Should -BeNullOrEmpty
    }

    It 'preserves a passing verdict for compliant PIM data' {
        & $CheckName | Should -BeTrue
        $script:SkippedBecause | Should -BeNullOrEmpty
    }

    It 'preserves a failing verdict for noncompliant PIM data' {
        $script:Compliant = $false

        & $CheckName | Should -BeFalse
        $script:SkippedBecause | Should -BeNullOrEmpty
    }
}

Describe 'CISA PIM native-engine outcome: <Id>' -ForEach @(
    @{ Id = 'CISA.MS.AAD.7.4' }
    @{ Id = 'CISA.MS.AAD.7.5' }
    @{ Id = 'CISA.MS.AAD.7.6' }
    @{ Id = 'CISA.MS.AAD.7.7' }
    @{ Id = 'CISA.MS.AAD.7.8' }
    @{ Id = 'CISA.MS.AAD.7.9' }
) {
    BeforeEach {
        Mock -ModuleName Maester Test-MtConnection { $true }
        Mock -ModuleName Maester Get-MgContext { $null }
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Get-MtRole {
            @(
                [pscustomobject]@{ id = '62e90394-69f5-4237-9190-012177145e10'; displayName = 'Global Administrator' }
                [pscustomobject]@{ id = '194ae4cb-b126-40b2-bd5b-6091b380977d'; displayName = 'Security Administrator' }
            )
        }
        $script:PimConfig = [pscustomobject]@{
            Environment = [pscustomobject]@{
                Licenses = @('AAD_PREMIUM_P2')
                Services = [pscustomobject]@{ Graph = $true }
            }
        }
    }

    It 'reports a licence rejection as Skipped, not Passed, Failed or Error' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-TestPimErrorRecord -Code 'AadPremiumLicenseRequired')
        }

        $row = Invoke-MtTest -Id $Id -Config $script:PimConfig

        $row.Result | Should -Be 'Skipped'
        $row.ResultDetail.TestSkipped | Should -Be 'NotLicensedEntraIDP2OrGovernance'
    }

    It 'reports permission failures as Error, not a licence skip' {
        Mock -ModuleName Maester Invoke-MtGraphRequest {
            throw (Get-TestPimErrorRecord -Code 'Authorization_RequestDenied')
        }

        $row = Invoke-MtTest -Id $Id -Config $script:PimConfig

        $row.Result | Should -Be 'Error'
        $row.ReasonCode | Should -Be 'TestError'
    }
}
