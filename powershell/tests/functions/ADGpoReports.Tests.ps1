BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtAdGpoCpasswordFoundCount, Test-MtAdGpoVersionMismatchCount, Test-MtCheckADGPOREP12, Test-MtAdGpoNoApplyGroupPolicyAceCount, Test-MtAdGpoNoPermissionsCount, Test-MtAdGpoNoAuthenticatedUsersCount
}

Describe 'Merged AD GPO report checks' {
    BeforeEach {
        $script:detail = $null
        $script:report = [PSCustomObject]@{
            Name = 'Example GPO'
            CpasswordFound = $false
            DefaultPasswordFound = $false
            HasVersionMismatch = $false
            DirectoryVersion = 65538
            SysvolVersion = 65538
            Errors = @()
            HasApplyGroupPolicyAce = $true
            PermissionsPresent = $true
            HasAuthenticatedUsers = $true
        }
        $script:state = [PSCustomObject]@{
            GPOs = @([PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000001'; DisplayName = 'Example GPO' })
            GPOReports = @($script:report)
            GPOLinks = @()
        }
        Mock Get-MtADGpoState -ModuleName Maester { $script:state }
        Mock Add-MtTestResultDetail -ModuleName Maester { $script:detail = $Result }
    }

    It 'passes only after both secret scan flags are evaluated' {
        Test-MtAdGpoCpasswordFoundCount | Should -BeTrue
        $script:detail | Should -Match 'Well done'
    }

    It 'fails when a GPO has no permissions and lists its name' {
        $script:report.PermissionsPresent = $false
        Test-MtAdGpoNoPermissionsCount | Should -BeFalse
        $script:detail | Should -Match 'Example GPO'
    }

    It 'marks unreadable permissions for investigation' {
        $script:report.PermissionsPresent = $null
        Test-MtAdGpoNoPermissionsCount | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
    }

    It 'investigates alternative security filtering rather than failing Authenticated Users absence' {
        $script:report.HasAuthenticatedUsers = $false
        Test-MtAdGpoNoAuthenticatedUsersCount | Should -BeTrue
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -Exactly 1 -ParameterFilter { $Investigate }
        $script:detail | Should -Match 'Example GPO'
    }

    It 'passes when application rights are present' {
        Test-MtAdGpoNoApplyGroupPolicyAceCount | Should -BeTrue
        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'fails when application rights are absent' {
        $script:report.HasApplyGroupPolicyAce = $false
        Test-MtAdGpoNoApplyGroupPolicyAceCount | Should -BeFalse
        $script:detail | Should -Match 'Example GPO'
    }

    It 'errors rather than passing when application rights are unreadable' {
        $script:report.HasApplyGroupPolicyAce = $null
        { Test-MtAdGpoNoApplyGroupPolicyAceCount } | Should -Throw '*could not be evaluated*'
    }

    It 'fails on cpassword alone without rendering the secret value' {
        $script:report.CpasswordFound = $true
        $script:report | Add-Member -NotePropertyName Password -NotePropertyValue 'SECRET-MUST-NOT-PRINT'
        Test-MtAdGpoCpasswordFoundCount | Should -BeFalse
        $script:detail | Should -Match 'Example GPO'
        $script:detail | Should -Not -Match 'SECRET-MUST-NOT-PRINT'
    }

    It 'fails on a default password alone' {
        $script:report.DefaultPasswordFound = $true
        Test-MtAdGpoCpasswordFoundCount | Should -BeFalse
        $script:detail | Should -Match 'default passwords'
    }

    It 'errors on null or missing scan flags and on SYSVOL collection errors' -ForEach @(
        @{ Case = 'missing cpassword flag' }
        @{ Case = 'missing default password flag' }
        @{ Case = 'SYSVOL error' }
    ) {
        switch ($Case) {
            'missing cpassword flag' { $script:report.CpasswordFound = $null }
            'missing default password flag' { $script:report.DefaultPasswordFound = $null }
            'SYSVOL error' { $script:report.Errors = @([PSCustomObject]@{ Transport = 'SYSVOL'; Message = 'failed' }) }
        }
        { Test-MtAdGpoCpasswordFoundCount } | Should -Throw '*incomplete*'
    }

    It 'errors if report collection silently drops a GPO' {
        $script:state.GPOs += [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000002'; DisplayName = 'Other GPO' }
        { Test-MtAdGpoCpasswordFoundCount } | Should -Throw '*inventory*'
    }

    It 'shows both versions for mismatched policies' {
        $script:report.HasVersionMismatch = $true
        $script:report.SysvolVersion = 65539
        Test-MtAdGpoVersionMismatchCount | Should -BeFalse
        $script:detail | Should -Match '65538 \| 65539'
    }

    It 'does not pass when SYSVOL version is missing' {
        $script:report.SysvolVersion = $null
        { Test-MtAdGpoVersionMismatchCount } | Should -Throw '*incomplete*'
    }

    It 'inventories disabled links and lists their linked container' {
        $script:state.GPOLinks = @([PSCustomObject]@{
                GpoGuid = '00000000-0000-0000-0000-000000000001'
                DistinguishedName = 'OU=Clients,DC=example,DC=com'
                IsDisabled = $true
            })
        Test-MtCheckADGPOREP12 | Should -BeTrue
        $script:detail | Should -Match '1 disabled links'
        $script:detail | Should -Match 'OU=Clients'
    }
}
