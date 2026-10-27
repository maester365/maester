Describe 'Active Directory DACL tests read AccessControlType as the collector emits it' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
        . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
        # Check functions that became native tests are not exported.
        Use-MtModuleFunction -Name @(
            'Test-MtAdDaclIdentityAceDistribution'
            'Test-MtAdDaclPrivilegedAllowAceCount'
            'Test-MtAdDaclPrivilegedAllowAceDetails'
            'Test-MtAdDaclPrivilegedExtendedRightCount'
            'Test-MtAdDaclPrivilegedExtendedRightDetails'
        )

        $domainSid = 'S-1-5-21-1004336348-1177238915-682003330'
        $helpdesk = "$domainSid-1105"
        $serviceAccount = "$domainSid-1106"
        $contractors = "$domainSid-1107"
        $resetPassword = '00299570-246d-11d0-a768-00aa006e0529'
        $changePassword = 'ab721a53-1e2f-11d0-9819-00aa0040529b'
        $noObjectType = [guid]::Empty.ToString()

        # One row per ACE in the DACL of OU=Sales: its SDDL form, followed by what
        # ConvertFrom-MtLdapSecurityDescriptor emits for it. Every raw allow/deny ACE type is covered.
        $script:Aces = @(
            [PSCustomObject]@{ Sddl = "(A;;0xf01ff;;;$helpdesk)"; AceType = 'AccessAllowed'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'GenericAll'; ObjectType = $noObjectType; Sid = $helpdesk }
            [PSCustomObject]@{ Sddl = "(A;CI;0xc0000;;;$serviceAccount)"; AceType = 'AccessAllowed'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'WriteDacl, WriteOwner'; ObjectType = $noObjectType; Sid = $serviceAccount }
            [PSCustomObject]@{ Sddl = "(A;;0x10;;;$contractors)"; AceType = 'AccessAllowed'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'ReadProperty'; ObjectType = $noObjectType; Sid = $contractors }
            [PSCustomObject]@{ Sddl = "(OA;;0x100;$resetPassword;;$helpdesk)"; AceType = 'AccessAllowedObject'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'ExtendedRight'; ObjectType = $resetPassword; Sid = $helpdesk }
            [PSCustomObject]@{ Sddl = "(OA;;0x100;$changePassword;;$serviceAccount)"; AceType = 'AccessAllowedObject'; AccessControlType = 'Allow'; ActiveDirectoryRights = 'ExtendedRight'; ObjectType = $changePassword; Sid = $serviceAccount }
            [PSCustomObject]@{ Sddl = "(D;;0xf01ff;;;$contractors)"; AceType = 'AccessDenied'; AccessControlType = 'Deny'; ActiveDirectoryRights = 'GenericAll'; ObjectType = $noObjectType; Sid = $contractors }
            [PSCustomObject]@{ Sddl = "(OD;;0x100;$resetPassword;;$contractors)"; AceType = 'AccessDeniedObject'; AccessControlType = 'Deny'; ActiveDirectoryRights = 'ExtendedRight'; ObjectType = $resetPassword; Sid = $contractors }
        )
        $script:SecurityDescriptorSddl = "O:$($helpdesk)G:$($helpdesk)D:" + (-join $script:Aces.Sddl)

        # Get-MtLdapDacl adds the object's identity to each ACE. The SIDs do not resolve, so the
        # converter falls back to the SID as the IdentityReference.
        $script:DaclEntries = @(
            foreach ($ace in $script:Aces) {
                [PSCustomObject]@{
                    ObjectDN              = 'OU=Sales,DC=contoso,DC=com'
                    ObjectClass           = 'organizationalUnit'
                    ObjectName            = 'Sales'
                    AccessControlType     = $ace.AccessControlType
                    AceType               = $ace.AceType
                    ActiveDirectoryRights = $ace.ActiveDirectoryRights
                    IdentityReference     = $ace.Sid
                    ObjectType            = $ace.ObjectType
                    Sid                   = $ace.Sid
                }
            }
        )
    }

    BeforeEach {
        $script:Result = $null

        Mock -ModuleName Maester Get-MtADDomainState { [PSCustomObject]@{ DaclEntries = $script:DaclEntries } }
        Mock -ModuleName Maester Add-MtTestResultDetail {
            param($Result)
            $script:Result = $Result
        }
    }

    # The converter parses with RawSecurityDescriptor, which .NET only implements on Windows.
    It 'uses a fixture that matches what ConvertFrom-MtLdapSecurityDescriptor emits' -Skip:($env:OS -ne 'Windows_NT') {
        $descriptor = [System.Security.AccessControl.RawSecurityDescriptor]::new($script:SecurityDescriptorSddl)
        $rawSecurityDescriptor = [byte[]]::new($descriptor.BinaryLength)
        $descriptor.GetBinaryForm($rawSecurityDescriptor, 0)

        $emitted = InModuleScope Maester -Parameters @{ RawSecurityDescriptor = $rawSecurityDescriptor } {
            @((ConvertFrom-MtLdapSecurityDescriptor -RawSecurityDescriptor $RawSecurityDescriptor).Access)
        }

        $emitted.Count | Should -Be $script:Aces.Count
        for ($i = 0; $i -lt $script:Aces.Count; $i++) {
            foreach ($property in 'AceType', 'AccessControlType', 'ActiveDirectoryRights', 'ObjectType', 'Sid') {
                $emitted[$i].$property | Should -Be $script:Aces[$i].$property -Because "$property of ACE $($script:Aces[$i].Sddl)"
            }
        }
    }

    It 'AD-DACL-08 (Test-MtAdDaclIdentityAceDistribution) splits the ACEs of each identity into allow and deny' {
        Test-MtAdDaclIdentityAceDistribution | Should -BeTrue

        # IdentityReference | ACE Count | Distinct Objects | Allow ACEs | Deny ACEs
        $script:Result | Should -BeLike "*| $helpdesk | 2 | 1 | 2 | 0 |*"
        $script:Result | Should -BeLike "*| $serviceAccount | 2 | 1 | 2 | 0 |*"
        $script:Result | Should -BeLike "*| $contractors | 3 | 1 | 1 | 2 |*"
    }

    It 'AD-DACL-09 (Test-MtAdDaclPrivilegedAllowAceCount) counts allow ACEs with privileged rights and ignores deny ACEs' {
        Test-MtAdDaclPrivilegedAllowAceCount | Should -BeTrue

        $script:Result | Should -BeLike '*| Total DACL ACEs | 7 |*'
        $script:Result | Should -BeLike '*| Privileged allow ACEs | 4 |*'
        $script:Result | Should -BeLike '*| Distinct objects with privileged allow ACEs | 1 |*'
        $script:Result | Should -BeLike '*| Distinct identities with privileged allow ACEs | 2 |*'
        $script:Result | Should -BeLike '*| ACEs containing GenericAll | 1 |*'
        $script:Result | Should -BeLike '*| ACEs containing WriteDacl | 1 |*'
        $script:Result | Should -BeLike '*| ACEs containing WriteOwner | 1 |*'
        $script:Result | Should -BeLike '*| ACEs containing ExtendedRight | 2 |*'
    }

    It 'AD-DACL-10 (Test-MtAdDaclPrivilegedAllowAceDetails) lists the object that holds privileged allow ACEs' {
        Test-MtAdDaclPrivilegedAllowAceDetails | Should -BeTrue

        # Object Name | Object Class | ACE Count | Distinct Identities | Privileged Rights | Object DN
        $script:Result | Should -BeLike '*| Sales | organizationalUnit | 4 | 2 | ExtendedRight, GenericAll, WriteDacl, WriteOwner | OU=Sales,DC=contoso,DC=com |*'
    }

    It 'AD-DACL-11 (Test-MtAdDaclPrivilegedExtendedRightCount) counts ExtendedRight allow ACEs and ignores deny ACEs' {
        Test-MtAdDaclPrivilegedExtendedRightCount | Should -BeTrue

        $script:Result | Should -BeLike '*| Total DACL ACEs | 7 |*'
        $script:Result | Should -BeLike '*| ExtendedRight allow ACEs | 2 |*'
        $script:Result | Should -BeLike '*| Distinct ObjectType values | 2 |*'
        $script:Result | Should -BeLike '*| Distinct identities with ExtendedRight | 2 |*'
        $script:Result | Should -BeLike '*| Distinct objects with ExtendedRight | 1 |*'
    }

    It 'AD-DACL-12 (Test-MtAdDaclPrivilegedExtendedRightDetails) lists each ObjectType granted through an ExtendedRight allow ACE' {
        Test-MtAdDaclPrivilegedExtendedRightDetails | Should -BeTrue

        # ObjectType | ACE Count | Distinct Objects | Distinct Identities
        $script:Result | Should -BeLike "*| $resetPassword | 1 | 1 | 1 |*"
        $script:Result | Should -BeLike "*| $changePassword | 1 | 1 | 1 |*"
    }
}
