BeforeAll {
    . "$PSScriptRoot/../../internal/checks/ad/ad/Test-MtAdUserOrdinaryIdentity.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Get-MtAdUserPathFindings.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Format-MtAdUserSecurityTable.ps1"
    . "$PSScriptRoot/../../internal/checks/ad/ad/Assert-MtAdUserAccountControl.ps1"
}

Describe 'Native USER security outcomes' {
    BeforeAll { Import-Module "$PSScriptRoot/../../Maester.psd1" -Force }
    BeforeEach {
        $script:batchDetail = $null
        $script:batchState = [pscustomobject]@{
            Domain = [pscustomobject]@{ DomainSID = 'S-1-5-21-1-2-3' }
            Users = @([pscustomobject]@{
                    Sid = 'S-1-5-21-1-2-3-1100'; SamAccountName = 'ordinary'; Name = 'ordinary'
                    DistinguishedName = 'CN=ordinary,OU=Staff,DC=example,DC=com'
                    Enabled = $false; Modified = (Get-Date).AddDays(-365); Created = (Get-Date).AddYears(-2)
                    UserAccountControl = 514; PasswordNotRequired = $false; PrimaryGroupId = 513
                    IsCriticalSystemObject = $false; SecondaryKrbtgtNumber = $null; KrbtgtLinkBacklinks = @()
                    Manager = ''; HomeDirectory = ''; ProfilePath = ''; ScriptPath = ''
                })
        }
        Mock -ModuleName Maester Get-MtADDomainState { $script:batchState }
        Mock -ModuleName Maester Add-MtTestResultDetail { $script:batchDetail = $Result }
    }
    It 'fails old disabled ordinary accounts but not fresh offboarding records' {
        InModuleScope Maester { Test-MtAdUserDisabledCount | Should -BeFalse }
        $script:batchState.Users[0].Modified = Get-Date
        InModuleScope Maester { Test-MtAdUserDisabledCount | Should -BeTrue }
    }
    It 'retains protected disabled identities' -ForEach @(@{ Kind = 'Critical' }, @{ Kind = 'DefaultAccount' }, @{ Kind = 'RODC' }, @{ Kind = 'AzureAD' }) {
        switch ($Kind) {
            'Critical' { $script:batchState.Users[0].IsCriticalSystemObject = $true }
            'DefaultAccount' { $script:batchState.Users[0].Sid = 'S-1-5-21-1-2-3-503' }
            'RODC' { $script:batchState.Users[0].SecondaryKrbtgtNumber = 1234 }
            'AzureAD' { $script:batchState.Users[0].SamAccountName = 'krbtgt_AzureAD' }
        }
        InModuleScope Maester { Test-MtAdUserDisabledCount | Should -BeTrue }
    }
    It 'errors on unavailable account identity rather than weakening lifecycle exclusions' {
        $script:batchState.Users[0].Sid = $null
        InModuleScope Maester { { Test-MtAdUserDisabledCount } | Should -Throw '*SID is unavailable*' }
    }
    It 'honors the configurable manager exclusion' {
        $script:batchState.Users[0].Enabled = $true
        InModuleScope Maester { Test-MtAdUserManagerSetCount | Should -BeFalse }
        InModuleScope Maester { Test-MtAdUserManagerSetCount -ExcludedUsers 'ordinary' | Should -BeTrue }
    }
    It 'uses a supported string-array primary-group parameter' {
        $script:batchState.Users[0].PrimaryGroupId = 600
        InModuleScope Maester {
            Test-MtAdUserNonStandardPrimaryGroupCount | Should -BeFalse
            Test-MtAdUserNonStandardPrimaryGroupCount -AllowedPrimaryGroupIds '513', '600' | Should -BeTrue
        }
    }
    It 'shows enabled password-not-required accounts without claiming a blank password' {
        $script:batchState.Users[0].Enabled = $true
        $script:batchState.Users[0].UserAccountControl = 544
        $script:batchState.Users[0].PasswordNotRequired = $true
        InModuleScope Maester { Test-MtAdUserPasswordNotRequiredCount | Should -BeFalse }
        $script:batchDetail | Should -Match 'does not prove a blank password'
        $script:batchDetail | Should -Match 'True'
    }
    It 'fails reversible-encryption configuration rather than merely counting it' {
        InModuleScope Maester { Test-MtAdUserReversibleEncryptionCount | Should -BeTrue }
        $script:batchState.Users[0].UserAccountControl = 642
        InModuleScope Maester { Test-MtAdUserReversibleEncryptionCount | Should -BeFalse }
        $script:batchDetail | Should -Match 'reset affected passwords'
    }
    It 'does not fail protected disabled Guest defaults but fails an enabled Guest' {
        $script:batchState.Users[0].Sid = 'S-1-5-21-1-2-3-501'
        $script:batchState.Users[0].UserAccountControl = 66082
        InModuleScope Maester { Test-MtAdUserPasswordNotRequiredCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        $script:batchState.Users[0].Enabled = $true
        InModuleScope Maester { Test-MtAdUserPasswordNotRequiredCount | Should -BeFalse }
    }
    It 'fails unapproved paths but permits approved roots and investigates relative scripts' {
        $script:batchState.Users[0].HomeDirectory = '\\files\staff\ordinary'
        InModuleScope Maester { Test-MtAdUserHomeDirectoryCount | Should -BeFalse }
        InModuleScope Maester { Test-MtAdUserHomeDirectoryCount -ApprovedPathPrefixes '\\files\staff' | Should -BeTrue }
        $script:batchState.Users[0].ScriptPath = 'staff.cmd'
        InModuleScope Maester { Test-MtAdUserHomeDirectoryCount -ApprovedPathPrefixes '\\files\staff' | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
    }
    It 'uses the domain RID-500 identity and refuses an unknown enabled state' {
        $script:batchState.Users[0].Sid = 'S-1-5-21-1-2-3-500'
        $script:batchState.Users[0] | Add-Member -NotePropertyName PasswordLastSet -NotePropertyValue (Get-Date).AddDays(-30)
        $script:batchState.Users[0] | Add-Member -NotePropertyName LastLogonDate -NotePropertyValue (Get-Date).AddDays(-35)
        $script:batchState.Users[0].Enabled = $true
        InModuleScope Maester { Test-MtAdUserBuiltInAdminCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        $script:batchState.Users[0].Enabled = $null
        InModuleScope Maester { { Test-MtAdUserBuiltInAdminCount } | Should -Throw '*enabled state is unavailable*' }
    }
    It 'uses a larger collected logon synchronization interval for RID-500 ambiguity' {
        $script:batchState.Domain | Add-Member -NotePropertyName LogonTimeSyncIntervalDays -NotePropertyValue 90
        $script:batchState.Users[0].Sid = 'S-1-5-21-1-2-3-500'
        $script:batchState.Users[0].Enabled = $true
        $script:batchState.Users[0] | Add-Member -NotePropertyName PasswordLastSet -NotePropertyValue (Get-Date).AddDays(-30)
        $script:batchState.Users[0] | Add-Member -NotePropertyName LastLogonDate -NotePropertyValue (Get-Date).AddDays(-60)
        InModuleScope Maester { Test-MtAdUserBuiltInAdminCount | Should -BeTrue }
        Should -Invoke Add-MtTestResultDetail -ModuleName Maester -ParameterFilter { $Investigate }
        $script:batchDetail | Should -Match '\| Conservative replication lag allowance \(days\) \| 90 \|'
    }
}

Describe 'AD user security batch helpers' {
    It 'excludes protected built-in and secondary krbtgt users without relying on names of ordinary users' {
        (Test-MtAdUserOrdinaryIdentity ([pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-500'; SamAccountName = 'renamed-admin' })) | Should -BeFalse
        (Test-MtAdUserOrdinaryIdentity ([pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1100'; SamAccountName = 'krbtgt_AzureAD_test' })) | Should -BeFalse
        (Test-MtAdUserOrdinaryIdentity ([pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1101'; SamAccountName = 'ordinary-user'; KrbtgtLinkBacklinks = @('CN=RODC') })) | Should -BeFalse
        (Test-MtAdUserOrdinaryIdentity ([pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1101'; SamAccountName = 'ordinary-user'; SecondaryKrbtgtNumber = 0 })) | Should -BeFalse
        (Test-MtAdUserOrdinaryIdentity ([pscustomobject]@{ Sid = 'S-1-5-21-1-2-3-1102'; SamAccountName = 'ordinary-user' })) | Should -BeTrue
    }

    It 'requires approved path component boundaries, allows case-insensitive prefixes and reviews relative scripts' {
        $users = @(
            [pscustomobject]@{ SamAccountName = 'allowed'; HomeDirectory = '\\server\home\allowed'; ProfilePath = $null; ScriptPath = 'staff.cmd' },
            [pscustomobject]@{ SamAccountName = 'evil'; HomeDirectory = '\\server\homeevil\evil'; ProfilePath = '\\server\home\..\secret'; ScriptPath = $null }
        )
        $findings = @(Get-MtAdUserPathFindings $users @('\\SERVER\HOME'))
        @($findings | Where-Object { $_.SamAccountName -eq 'allowed' -and $_.Field -eq 'HomeDirectory' }).Count | Should -Be 0
        @($findings | Where-Object { $_.Finding -eq 'Unapproved path' }).Count | Should -Be 1
        @($findings | Where-Object { $_.Finding -eq 'Parent traversal (reject)' }).Count | Should -Be 1
        @($findings | Where-Object { $_.Finding -like 'Relative NETLOGON*' }).Count | Should -Be 1
    }

    It 'escapes markdown cell separators in reported account names' {
        (Format-MtAdUserSecurityTable @([pscustomobject]@{ SamAccountName = 'a|b' }) @('SamAccountName')) | Should -Match 'a\\\|b'
    }

    It 'does not interpret unavailable account control as a cleared security flag' {
        { Assert-MtAdUserAccountControl @([pscustomobject]@{ SamAccountName = 'missing'; UserAccountControl = $null }) } | Should -Throw '*unavailable*'
    }
}
