BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
    . "$PSScriptRoot/../helpers/Use-MtModuleFunction.ps1"
    Use-MtModuleFunction -Name Test-MtAdGroupMemberDistinctGroupCount, Test-MtAdGroupMemberAccountTypeCount,
    Test-MtAdGroupMemberTrustCount, Test-MtAdUserSpnTotalCount, Test-MtAdUserSpnServiceClassCount,
    Test-MtAdUserSpnDomainAdminCount, Test-MtAdGroupStaleCount
    Use-MtModuleFunction -Name Test-MtAdGroupMemberForeignSidCount, Test-MtAdGroupEmptyNonPrivilegedCount, Test-MtAdGroupPrivilegedWithMembersCount
}

Describe 'AD group and SPN checks on a collected snapshot' {
    It 'errors rather than treating missing group modification timestamps as recent' {
        InModuleScope Maester {
            { Test-MtAdGroupStaleCount } | Should -Throw '*modification timestamps are missing*'
        }
    }
    BeforeEach {
        InModuleScope Maester {
            $script:adSpnDomainSid = 'S-1-5-21-111-222-333'
            $script:adSpnAdminDn = 'CN=Domain Admins,DC=example,DC=com'
            $script:adSpnState = [PSCustomObject]@{
                Domain = [PSCustomObject]@{ DomainSID = [PSCustomObject]@{ Value = $script:adSpnDomainSid } }
                Groups = @([PSCustomObject]@{ DistinguishedName = $script:adSpnAdminDn; SID = [PSCustomObject]@{ Value = "$script:adSpnDomainSid-512" }; Name = 'Domain Admins' })
                Users = @([PSCustomObject]@{ DistinguishedName = 'CN=Ordinary,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1100"; SamAccountName = 'ordinary'; PrimaryGroupId = 513; ServicePrincipalName = @() })
                ProtocolEvidence = [PSCustomObject]@{}
            }
            $script:adSpnMembers = @{ $script:adSpnAdminDn = @() }
            $script:adSpnResult = ''
            $script:adConnectionDisposed = $false
        }

        Mock Get-MtADDomainState -ModuleName Maester { InModuleScope Maester { $script:adSpnState } }
        Mock New-MtAdProtocolConnection -ModuleName Maester {
            [PSCustomObject]@{} | Add-Member -MemberType ScriptMethod -Name Dispose -Value {
                InModuleScope Maester { $script:adConnectionDisposed = $true }
            } -PassThru
        }
        Mock Get-MtLdapGroupMember -ModuleName Maester -RemoveParameterType Connection {
            InModuleScope Maester -Parameters @{ GroupDn = $GroupDistinguishedName } {
                @($script:adSpnMembers[$GroupDn]) | Where-Object { $null -ne $_ }
            }
        }
        Mock Add-MtTestResultDetail -ModuleName Maester {
            InModuleScope Maester -Parameters @{ Detail = $Result } { $script:adSpnResult = $Detail }
        }
    }

    It 'counts members in group 51 instead of silently truncating at 50' {
        InModuleScope Maester {
            $script:adSpnState.Groups = @(1..51 | ForEach-Object {
                [PSCustomObject]@{ DistinguishedName = "CN=G$_,DC=example,DC=com"; Name = "G$_"; SID = "$script:adSpnDomainSid-$_" }
            })
            $script:adSpnMembers['CN=G51,DC=example,DC=com'] = @(
                [PSCustomObject]@{ SID = "$script:adSpnDomainSid-1200"; DistinguishedName = 'CN=Member,DC=example,DC=com'; Name = 'Member'; ObjectClass = 'user' }
            )
            Test-MtAdGroupMemberDistinctGroupCount | Should -BeTrue
            $script:adSpnResult | Should -Match '1 out of 51 groups'
            Test-MtAdGroupMemberAccountTypeCount | Should -BeTrue
            $script:adSpnResult | Should -Match '1 distinct account types across 1 unique members'
        }
    }

    It 'disposes the LDAP connection when a complete group scan errors' -ForEach @(
        @{ Command = 'Test-MtAdGroupMemberDistinctGroupCount' }
        @{ Command = 'Test-MtAdGroupMemberAccountTypeCount' }
        @{ Command = 'Test-MtAdGroupMemberForeignSidCount' }
        @{ Command = 'Test-MtAdGroupMemberTrustCount' }
        @{ Command = 'Test-MtAdGroupPrivilegedWithMembersCount' }
        @{ Command = 'Test-MtAdGroupEmptyNonPrivilegedCount' }
    ) {
        Mock Get-MtLdapGroupMember -ModuleName Maester -RemoveParameterType Connection { throw 'Membership read failed' }
        InModuleScope Maester -Parameters @{ Name = $Command } {
            $script:adSpnState.Groups[0] | Add-Member -NotePropertyName adminCount -NotePropertyValue 1 -Force
            { & $Name } | Should -Throw '*Membership read failed*'
            $script:adConnectionDisposed | Should -BeTrue
        }
    }

    It 'classifies foreign domain-account SIDs without treating well-known or current-domain SIDs as foreign' {
        InModuleScope Maester {
            $script:adSpnMembers[$script:adSpnAdminDn] = @(
                [pscustomobject]@{ SID = 'S-1-5-18'; Name = 'SYSTEM' }
                [pscustomobject]@{ SID = "$script:adSpnDomainSid-1200"; Name = 'Local' }
                [pscustomobject]@{ SID = 'S-1-5-21-444-555-666-1200'; Name = 'Foreign string' }
                [pscustomobject]@{ SID = [pscustomobject]@{ Value = 'S-1-5-21-111-222-3334-1200' }; Name = 'Different domain sharing text prefix' }
            )
            Test-MtAdGroupMemberForeignSidCount | Should -BeTrue
            $script:adSpnResult | Should -Match 'Foreign SID Principals \| 2'
            $script:adSpnResult | Should -Not -Match '\| SYSTEM \|'
            $script:adConnectionDisposed | Should -BeTrue
        }
    }

    It 'accepts a string domain SID for foreign-member classification' {
        InModuleScope Maester {
            $script:adSpnState.Domain.DomainSID = $script:adSpnDomainSid
            $script:adSpnMembers[$script:adSpnAdminDn] = @([pscustomobject]@{ SID = 'S-1-5-21-444-555-666-1200'; Name = 'Foreign' })
            Test-MtAdGroupMemberForeignSidCount | Should -BeTrue
            $script:adSpnResult | Should -Match 'Foreign SID Principals \| 1'
        }
    }

    It 'counts trust principals from group 51 without classifying NT AUTHORITY SIDs as foreign domains' {
        InModuleScope Maester {
            $script:adSpnState.Groups = @(1..51 | ForEach-Object {
                [PSCustomObject]@{ DistinguishedName = "CN=G$_,DC=example,DC=com"; Name = "G$_"; SID = "$script:adSpnDomainSid-$_" }
            })
            $script:adSpnMembers['CN=G51,DC=example,DC=com'] = @(
                [PSCustomObject]@{ SID = 'S-1-5-18'; DistinguishedName = 'CN=System,DC=example,DC=com'; Name = 'SYSTEM'; ObjectClass = 'user' },
                [PSCustomObject]@{ SID = 'S-1-5-21-444-555-666-1200'; DistinguishedName = 'CN=Foreign,DC=example,DC=com'; Name = 'Foreign'; ObjectClass = 'foreignSecurityPrincipal' }
            )
            Test-MtAdGroupMemberTrustCount | Should -BeTrue
            $script:adSpnResult | Should -Match 'Found 1 trust members'
            $script:adSpnResult | Should -Match 'Groups Analyzed \| 51'
        }
    }

    It 'distinguishes two users with SPNs from seven raw SPNs' {
        InModuleScope Maester {
            $script:adSpnState.Users = @(
                [PSCustomObject]@{ SamAccountName = 'one'; ServicePrincipalName = @('HTTP/a', 'HTTP/b', 'custom:value') },
                [PSCustomObject]@{ SamAccountName = 'two'; ServicePrincipalName = @('HTTP/c', 'HTTP/d', 'HTTP/e', 'HTTP/f') },
                [PSCustomObject]@{ SamAccountName = 'none'; ServicePrincipalName = @() }
            )
            Test-MtAdUserSpnTotalCount | Should -BeTrue
            $script:adSpnResult | Should -Match '7 SPNs across 2 user accounts'
            Test-MtAdUserSpnServiceClassCount | Should -BeTrue
            $script:adSpnResult | Should -Match 'Total User SPNs \| 7'
            $script:adSpnResult | Should -Match 'Users with SPNs \| 2'
        }
    }

    It 'counts direct, nested and primary-group Domain Admins, including unparsed SPNs' {
        InModuleScope Maester {
            $nestedDn = 'CN=Nested,DC=example,DC=com'
            $script:adSpnState.Groups += [PSCustomObject]@{ DistinguishedName = $nestedDn; SID = "$script:adSpnDomainSid-1400"; Name = 'Nested' }
            $script:adSpnState.Users = @(
                [PSCustomObject]@{ DistinguishedName = 'CN=Direct,DC=example,DC=com'; SID = [PSCustomObject]@{ Value = "$script:adSpnDomainSid-1101" }; SamAccountName = 'direct'; PrimaryGroupId = 513; ServicePrincipalName = @('HTTP/host', 'not-standard') },
                [PSCustomObject]@{ DistinguishedName = 'CN=Indirect,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1102"; SamAccountName = 'indirect'; PrimaryGroupId = 513; ServicePrincipalName = @('HTTP/nested') },
                [PSCustomObject]@{ DistinguishedName = 'CN=Primary,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1103"; SamAccountName = 'primary'; PrimaryGroupId = 512; ServicePrincipalName = @('opaque-spn') },
                [PSCustomObject]@{ DistinguishedName = 'CN=OtherDomain,DC=example,DC=com'; SID = 'S-1-5-21-444-555-666-1104'; SamAccountName = 'other'; PrimaryGroupId = 512; ServicePrincipalName = @('HTTP/foreign') }
            )
            $script:adSpnMembers[$script:adSpnAdminDn] = @(
                [PSCustomObject]@{ DistinguishedName = 'CN=Direct,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1101" },
                [PSCustomObject]@{ DistinguishedName = $nestedDn; SID = "$script:adSpnDomainSid-1400" }
            )
            $script:adSpnMembers[$nestedDn] = @(
                [PSCustomObject]@{ DistinguishedName = 'CN=Indirect,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1102" }
            )
            Test-MtAdUserSpnDomainAdminCount | Should -BeFalse
            $script:adSpnResult | Should -Match 'Domain Admin Accounts \| 3'
            $script:adSpnResult | Should -Match 'Domain Admins with SPNs \| 3'
            $script:adSpnResult | Should -Match 'Total SPNs on Domain Admins \| 4'
        }
    }

    It 'terminates on cyclic nested groups and deduplicates the same user' {
        InModuleScope Maester {
            $nestedDn = 'CN=Nested,DC=example,DC=com'
            $script:adSpnState.Groups += [PSCustomObject]@{ DistinguishedName = $nestedDn; SID = "$script:adSpnDomainSid-1400"; Name = 'Nested' }
            $script:adSpnState.Users = @([PSCustomObject]@{
                DistinguishedName = 'CN=Direct,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1101"
                SamAccountName = 'direct'; PrimaryGroupId = 512; ServicePrincipalName = @()
            })
            $script:adSpnMembers[$script:adSpnAdminDn] = @(
                [PSCustomObject]@{ DistinguishedName = $nestedDn; SID = "$script:adSpnDomainSid-1400" },
                [PSCustomObject]@{ DistinguishedName = 'CN=Direct,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1101" }
            )
            $script:adSpnMembers[$nestedDn] = @(
                [PSCustomObject]@{ DistinguishedName = $script:adSpnAdminDn; SID = "$script:adSpnDomainSid-512" },
                [PSCustomObject]@{ DistinguishedName = 'CN=Direct,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1101" }
            )
            Test-MtAdUserSpnDomainAdminCount | Should -BeTrue
            $script:adSpnResult | Should -Match 'Domain Admin Accounts \| 1'
        }
    }

    It 'errors instead of reporting a clean Domain Admins result when membership is unresolved' {
        InModuleScope Maester {
            $script:adSpnMembers[$script:adSpnAdminDn] = @(
                [PSCustomObject]@{ DistinguishedName = 'CN=Missing,DC=example,DC=com'; SID = "$script:adSpnDomainSid-1999" }
            )
            { Test-MtAdUserSpnDomainAdminCount } | Should -Throw '*Unresolved Domain Admins member*'
            $script:adSpnResult | Should -BeNullOrEmpty
        }
    }
}
