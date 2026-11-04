BeforeAll {
    Import-Module $PSScriptRoot/../../Maester.psd1 -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    # Check functions that became native tests are not exported.
    Use-MtModuleFunction -Name Test-MtCisaPermanentRoleAssignment, Test-MtCisaUnmanagedRoleAssignment, Test-MtCisaRequireActivationApproval, Test-MtCisaAssignmentNotification, Test-MtCisaActivationNotification
}

Describe 'CISA PIM checks when the PIM APIs reject the tenant license' -Tag 'Unit' -ForEach @(
    @{ Command = 'Test-MtCisaPermanentRoleAssignment'; Parameters = @{} }
    @{ Command = 'Test-MtCisaUnmanagedRoleAssignment'; Parameters = @{} }
    @{ Command = 'Test-MtCisaRequireActivationApproval'; Parameters = @{} }
    @{ Command = 'Test-MtCisaAssignmentNotification'; Parameters = @{} }
    @{ Command = 'Test-MtCisaActivationNotification'; Parameters = @{} }
    @{ Command = 'Test-MtCisaActivationNotification'; Parameters = @{ GlobalAdminOnly = $true } }
) {
    BeforeAll {
        function Get-GraphErrorRecord ([string]$Code) {
            $errorRecord = [System.Management.Automation.ErrorRecord]::new(
                [System.Exception]::new('Response status code does not indicate success.'),
                'InvokeGraphHttpResponseException',
                [System.Management.Automation.ErrorCategory]::InvalidOperation,
                $null
            )
            $errorRecord.ErrorDetails = [System.Management.Automation.ErrorDetails]::new("{`"error`":{`"code`":`"$Code`"}}")
            $errorRecord
        }
    }

    BeforeEach {
        Mock -ModuleName Maester Get-MtLicenseInformation { 'P2' }
        Mock -ModuleName Maester Get-MtRole {
            [pscustomobject]@{ id = '62e90394-69f5-4237-9190-012177145e10'; displayName = 'Global Administrator' }
            [pscustomobject]@{ id = 'e8611ab8-c189-46e8-94e1-60213ab1f814'; displayName = 'Privileged Role Administrator' }
        }
        Mock -ModuleName Maester Add-MtTestResultDetail {}
    }

    It '<Command> skips on AadPremiumLicenseRequired' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-GraphErrorRecord -Code 'AadPremiumLicenseRequired') }

        & $Command @Parameters | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $SkippedBecause -eq 'NotLicensedEntraIDP2OrGovernance' }
    }

    It '<Command> skips on a non-terminating AadPremiumLicenseRequired error' {
        # The native engine runs checks with $ErrorActionPreference = 'Continue'
        $ErrorActionPreference = 'Continue'
        # Write the error from the module's scope, so it follows the caller's -ErrorAction like the Graph SDK does
        Mock -ModuleName Maester Invoke-MtGraphRequest { & (Get-Module Maester) { Write-Error -ErrorRecord $args[0] } (Get-GraphErrorRecord -Code 'AadPremiumLicenseRequired') }

        & $Command @Parameters | Should -BeNullOrEmpty

        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $SkippedBecause -eq 'NotLicensedEntraIDP2OrGovernance' }
    }

    It '<Command> rethrows other Graph errors' {
        Mock -ModuleName Maester Invoke-MtGraphRequest { throw (Get-GraphErrorRecord -Code 'Authorization_RequestDenied') }

        { & $Command @Parameters } | Should -Throw -ErrorId 'InvokeGraphHttpResponseException'
    }
}
