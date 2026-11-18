Describe 'Consolidated Active Directory DACL inventory' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        Use-MtModuleFunction -Name @(
            'Test-MtAdDaclConflictObjectCount'
            'Test-MtAdDaclDenyAceCount'
            'Test-MtAdDaclDistinctIdentityCount'
            'Test-MtAdDaclPrivilegedAllowAceCount'
            'Test-MtAdDaclPrivilegedExtendedRightCount'
            'Test-MtAdDaclUnresolvedSidCount'
            'Test-MtAdDaclInheritedObjectTypeCount'
        )
        $script:Entries = @(
            [PSCustomObject]@{ ObjectDN = 'CN=Dup\0ACNF:123,DC=example,DC=com'; ObjectClass = 'user'; ObjectName = 'Dup'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'GenericAll'; IdentityReference = 'S-1-5-21-1-2-3-99'; ObjectType = [guid]::Empty.ToString(); InheritedObjectType = '11111111-1111-1111-1111-111111111111' }
            [PSCustomObject]@{ ObjectDN = 'CN=Dup\0ACNF:123,DC=example,DC=com'; ObjectClass = 'user'; ObjectName = 'Dup'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'ReadProperty, ExtendedRight'; IdentityReference = 'EXAMPLE\Admin'; ObjectType = '00299570-246d-11d0-a768-00aa006e0529'; InheritedObjectType = '11111111-1111-1111-1111-111111111111' }
            [PSCustomObject]@{ ObjectDN = 'OU=Other,DC=example,DC=com'; ObjectClass = 'organizationalUnit'; ObjectName = 'Other'; AccessControlType = 'Deny'; ActiveDirectoryRights = 'ExtendedRight'; IdentityReference = 'EXAMPLE\Admin'; ObjectType = '00299570-246d-11d0-a768-00aa006e0529'; InheritedObjectType = [guid]::Empty.ToString() }
        )
    }

    BeforeEach {
        $script:Detail = $null
        Mock -ModuleName Maester Test-MtAdDaclPlatformSupported { $true }
        Mock -ModuleName Maester Get-MtADDomainState { [PSCustomObject]@{ DaclEntries = $script:Entries } }
        Mock -ModuleName Maester Add-MtTestResultDetail { param($Result) $script:Detail = $Result }
    }

    It 'keeps counts and object details together for conflict objects and deny ACEs' {
        Test-MtAdDaclConflictObjectCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| Conflict Objects In DACL Data | 1 |*'
        $script:Detail | Should -BeLike '*| CN=Dup* | user | 2 |*'
        Test-MtAdDaclDenyAceCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| Deny ACEs | 1 |*'
        $script:Detail | Should -BeLike '*| Other | organizationalUnit | OU=Other,DC=example,DC=com | EXAMPLE\Admin | 1 |*'
    }

    It 'reports identity distribution and distinct counts in one result' {
        Test-MtAdDaclDistinctIdentityCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| Distinct identities | 2 |*'
        $script:Detail | Should -BeLike '*| EXAMPLE\Admin | 2 | 2 | 1 | 1 |*'
    }

    It 'includes privileged allow objects and named extended-right identities without counting deny grants' {
        Test-MtAdDaclPrivilegedAllowAceCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| Privileged allow ACEs | 2 |*'
        $script:Detail | Should -BeLike '*| Dup | user | 2 | 2 | ExtendedRight, GenericAll |*'
        Test-MtAdDaclPrivilegedExtendedRightCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| ExtendedRight allow ACEs | 1 |*'
        $script:Detail | Should -BeLike '*| EXAMPLE\Admin | Reset Password | 1 |*'
    }

    It 'includes unresolved SID and inheritance-target breakdowns' {
        Test-MtAdDaclUnresolvedSidCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| Distinct Unresolved SIDs | 1 |*'
        $script:Detail | Should -BeLike '*| CN=Dup* | 1 | S-1-5-21-1-2-3-99 |*'
        Test-MtAdDaclInheritedObjectTypeCount | Should -BeTrue
        $script:Detail | Should -BeLike '*| Distinct InheritedObjectType GUIDs | 1 |*'
        $script:Detail | Should -BeLike '*| 11111111-1111-1111-1111-111111111111 | 2 | 1 |*'
    }

    It 'does not report an inventory from missing DACL data' {
        Mock -ModuleName Maester Get-MtADDomainState { [PSCustomObject]@{ DaclEntries = $null } }
        foreach ($check in @('Test-MtAdDaclConflictObjectCount', 'Test-MtAdDaclDenyAceCount', 'Test-MtAdDaclDistinctIdentityCount', 'Test-MtAdDaclPrivilegedAllowAceCount', 'Test-MtAdDaclPrivilegedExtendedRightCount', 'Test-MtAdDaclUnresolvedSidCount', 'Test-MtAdDaclInheritedObjectTypeCount')) {
            { & $check } | Should -Throw '*DACL data is unavailable*'
        }
    }
}
