BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Merged AD Group Policy checks' {
    BeforeEach {
        $script:report = [PSCustomObject]@{
            Name = 'Example | GPO'
            CpasswordFound = $false
            DefaultPasswordFound = $false
            HasVersionMismatch = $false
            DirectoryVersion = 65538
            SysvolVersion = 65538
            Errors = @()
            HasApplyGroupPolicyAce = $true
            PermissionsPresent = $true
            HasAuthenticatedUsers = $true
            HasDenyAce = $false
        }
        $script:state = [PSCustomObject]@{
            GPOs = @([PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000001'; DisplayName = 'Example | GPO' })
            GPOReports = @($script:report)
            GPOLinks = @()
        }
        Mock Get-MtADGpoState -ModuleName Maester { $script:state }
        Mock Add-MtTestResultDetail -ModuleName Maester { }
    }

    It 'passes only after both secret scan flags are evaluated' {
        InModuleScope Maester { Test-MtAdGpoCpasswordFoundCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'Well done' }
    }

    It 'fails on cpassword alone without rendering the secret value' {
        $script:report.CpasswordFound = $true
        $script:report | Add-Member -NotePropertyName Password -NotePropertyValue 'SECRET-MUST-NOT-PRINT'
        InModuleScope Maester { Test-MtAdGpoCpasswordFoundCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $Result -match 'Example &#124; GPO' -and $Result -notmatch 'SECRET-MUST-NOT-PRINT'
        }
    }

    It 'fails on a default password alone' {
        $script:report.DefaultPasswordFound = $true
        InModuleScope Maester { Test-MtAdGpoCpasswordFoundCount | Should -BeFalse }
    }

    It 'fails once for a policy exposing both password types' {
        $script:report.CpasswordFound = $true
        $script:report.DefaultPasswordFound = $true
        InModuleScope Maester { Test-MtAdGpoCpasswordFoundCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '1 of 1 GPOs expose passwords' }
    }

    It 'does not hide a known secret behind another incomplete scan' {
        $script:report.CpasswordFound = $true
        $script:report.DefaultPasswordFound = $null
        $script:report.Errors = @('unreadable file')
        InModuleScope Maester { Test-MtAdGpoCpasswordFoundCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'Unknown' -and $Result -match 'incomplete for 1 GPOs' }
    }

    It 'errors on incomplete scans without findings' -ForEach @(
        @{ Case = 'missing cpassword flag' }
        @{ Case = 'missing default password flag' }
        @{ Case = 'SYSVOL error' }
    ) {
        switch ($Case) {
            'missing cpassword flag' { $script:report.CpasswordFound = $null }
            'missing default password flag' { $script:report.DefaultPasswordFound = $null }
            'SYSVOL error' { $script:report.Errors = @('failed') }
        }
        InModuleScope Maester { { Test-MtAdGpoCpasswordFoundCount } | Should -Throw '*incomplete*' }
    }

    It 'errors if report collection silently drops a GPO' {
        $script:state.GPOs += [PSCustomObject]@{ Id = '00000000-0000-0000-0000-000000000002' }
        InModuleScope Maester { { Test-MtAdGpoCpasswordFoundCount } | Should -Throw '*inventory*' }
    }

    It 'shows both versions for mismatched policies' {
        $script:report.HasVersionMismatch = $true
        $script:report.SysvolVersion = 65539
        InModuleScope Maester { Test-MtAdGpoVersionMismatchCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match '65538 \| 65539' }
    }

    It 'passes matching versions' {
        InModuleScope Maester { Test-MtAdGpoVersionMismatchCount | Should -BeTrue }
    }

    It 'does not pass when a version is missing' -ForEach @('DirectoryVersion', 'SysvolVersion') {
        $script:report.$_ = $null
        InModuleScope Maester { { Test-MtAdGpoVersionMismatchCount } | Should -Throw '*incomplete*' }
    }

    It 'passes when application rights are present' {
        InModuleScope Maester { Test-MtAdGpoNoApplyGroupPolicyAceCount | Should -BeTrue }
        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'fails when application rights are absent and lists affected policies' {
        $script:report.HasApplyGroupPolicyAce = $false
        InModuleScope Maester { Test-MtAdGpoNoApplyGroupPolicyAceCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'Example &#124; GPO' -and -not $Investigate }
    }

    It 'errors rather than passing when application rights are unreadable' {
        $script:report.HasApplyGroupPolicyAce = $null
        InModuleScope Maester { { Test-MtAdGpoNoApplyGroupPolicyAceCount } | Should -Throw '*could not be evaluated*' }
    }

    It 'fails on deny ACEs and lists affected policies' {
        $script:report.HasDenyAce = $true
        InModuleScope Maester { Test-MtAdGpoDenyAceCount | Should -BeFalse }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Result -match 'Example &#124; GPO' -and -not $Investigate }
    }

    It 'does not pass unreadable deny ACEs' {
        $script:state.GPOReports += [PSCustomObject]@{ Name = 'Unreadable'; HasDenyAce = $null }
        InModuleScope Maester { Test-MtAdGpoDenyAceCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate -and $Result -match 'Unreadable' }
    }

    It 'inventories disabled and enforced links with their linked containers' {
        $script:state.GPOLinks = @([PSCustomObject]@{
                GpoGuid = '00000000-0000-0000-0000-000000000001'
                DistinguishedName = 'OU=Clients,DC=example,DC=com'
                Options = 3
                IsDisabled = $true
                IsEnforced = $true
            })
        InModuleScope Maester { Test-MtCheckADGPOREP12 | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter {
            $Investigate -and $Result -match '1 disabled links' -and $Result -match 'OU=Clients'
        }
    }

    It 'preserves the shared disabled-link helper default outcome' {
        InModuleScope Maester { Test-MtAdGpoDisabledLinkCount | Should -BeTrue }
        Should -Not -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }

    It 'errors on missing link collection instead of reporting zero disabled links' {
        $script:state.GPOLinks = $null
        InModuleScope Maester { { Test-MtCheckADGPOREP12 } | Should -Throw '*cannot inventory*' }
    }
}
