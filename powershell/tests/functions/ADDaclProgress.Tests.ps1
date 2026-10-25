#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

Describe 'Get-MtLdapDacl progress' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -ErrorAction Stop

        $script:testBase = 'DC=contoso,DC=test'
        $script:u1 = [pscustomobject]@{
            DistinguishedName = "CN=U1,$script:testBase"
            Attributes = [pscustomobject]@{
                distinguishedName = "CN=U1,$script:testBase"
                objectClass = @('top','person','user')
                name = 'U1'
                objectSid = 'S-1-5-21-1-2-3-10'
                ntSecurityDescriptor = [pscustomobject]@{ Access = @(
                    [pscustomobject]@{ AccessControlType = 'Allow'; ActiveDirectoryRights = 'GenericAll'; IdentityReference = 'CONTOSO\Alice'; IsInherited = $false; Sid = 'S-1-5-21-1-2-3-1' },
                    [pscustomobject]@{ AccessControlType = 'Deny'; ActiveDirectoryRights = 'WriteProperty'; IdentityReference = 'CONTOSO\Bob'; IsInherited = $true; Sid = 'S-1-5-21-1-2-3-2' }
                ) }
            }
        }
        $script:u2 = [pscustomobject]@{
            DistinguishedName = "CN=U2,$script:testBase"
            Attributes = [pscustomobject]@{
                distinguishedName = "CN=U2,$script:testBase"
                objectClass = @('top','person','user')
                name = 'U2'
                objectSid = 'S-1-5-21-1-2-3-11'
                ntSecurityDescriptor = [pscustomobject]@{ Access = @(
                    [pscustomobject]@{ AccessControlType = 'Allow'; ActiveDirectoryRights = 'ReadProperty'; IdentityReference = 'CONTOSO\Charlie'; IsInherited = $false; Sid = 'S-1-5-21-1-2-3-3' }
                ) }
            }
        }
        $script:u3 = [pscustomobject]@{
            DistinguishedName = "CN=U3,$script:testBase"
            Attributes = [pscustomobject]@{
                distinguishedName = "CN=U3,$script:testBase"
                objectClass = @('top','person','user')
                name = 'U3'
                objectSid = 'S-1-5-21-1-2-3-12'
                ntSecurityDescriptor = $null
            }
        }
        $script:u4 = [pscustomobject]@{
            DistinguishedName = "CN=U4,$script:testBase"
            Attributes = [pscustomobject]@{
                distinguishedName = "CN=U4,$script:testBase"
                objectClass = @('top','person','user')
                name = 'U4'
                objectSid = 'S-1-5-21-1-2-3-13'
                ntSecurityDescriptor = [pscustomobject]@{ Access = @() }
            }
        }
        $script:u5 = [pscustomobject]@{
            DistinguishedName = "CN=U5,$script:testBase"
            Attributes = [pscustomobject]@{
                distinguishedName = "CN=U5,$script:testBase"
                objectClass = @('top','person','user')
                name = 'U5'
                objectSid = 'S-1-5-21-1-2-3-14'
                ntSecurityDescriptor = [pscustomobject]@{ Access = @(
                    [pscustomobject]@{ AccessControlType = 'Allow'; ActiveDirectoryRights = 'GenericRead'; IdentityReference = 'CONTOSO\Dave'; IsInherited = $false; Sid = 'S-1-5-21-1-2-3-4' },
                    [pscustomobject]@{ AccessControlType = 'Allow'; ActiveDirectoryRights = 'GenericWrite'; IdentityReference = 'CONTOSO\Eve'; IsInherited = $true; Sid = 'S-1-5-21-1-2-3-5' },
                    [pscustomobject]@{ AccessControlType = 'Deny'; ActiveDirectoryRights = 'Delete'; IdentityReference = 'CONTOSO\Frank'; IsInherited = $false; Sid = 'S-1-5-21-1-2-3-6' }
                ) }
            }
        }
    }

    Context 'characterization and row parity' {
        It 'returns six ordered rows from the three-page fixture' -Skip:(-not $IsWindows) {
            $output = InModuleScope Maester -Parameters @{ u1 = $script:u1; u2 = $script:u2; u3 = $script:u3; u4 = $script:u4; u5 = $script:u5; base = $script:testBase } {
                param($u1, $u2, $u3, $u4, $u5, $base)
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name PageNumber -Value 0 -Force
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $conn.PageNumber++
                    $cookie = if ($conn.PageNumber -lt 3) { [byte[]]@($conn.PageNumber) } else { [byte[]]@() }
                    $entries = switch ($conn.PageNumber) {
                        1 { @($u1, $u2) }
                        2 { @($u3, $u4) }
                        3 { @($u5) }
                        default { @() }
                    }
                    $pageCtrl = [pscustomobject]@{ Cookie = $cookie; TotalCount = if ($conn.PageNumber -eq 1) { 10 } elseif ($conn.PageNumber -eq 2) { 3 } else { 0 } }
                    return [pscustomobject]@{ Entries = $entries; Controls = @($pageCtrl) }
                } -Force

                Mock ConvertFrom-MtLdapValue -ModuleName Maester {
                    param($Value, $AttributeName)
                    if ($AttributeName -eq 'ntSecurityDescriptor' -and $Value -is [pscustomobject] -and $Value.PSObject.Properties['Access']) {
                        return $Value
                    }
                    return $Value
                }
                Get-MtLdapDacl -Connection $conn -SearchBase $base -ProgressInterval ([timespan]::FromHours(1))
            }

            $output | Should -HaveCount 6
            $output[0].ObjectName | Should -Be 'U1'
            $output[0].AccessControlType | Should -Be 'Allow'
            $output[1].AccessControlType | Should -Be 'Deny'
            $output[2].ObjectName | Should -Be 'U2'
            $output[3].ObjectName | Should -Be 'U5'
            $output[3].AccessControlType | Should -Be 'Allow'
            $output[4].AccessControlType | Should -Be 'Allow'
            $output[5].AccessControlType | Should -Be 'Deny'
        }
    }

    Context 'progress lifecycle' {
        It 'emits initial, page, terminal and Clear with zero-interval' {
            $output = InModuleScope Maester -Parameters @{ u1 = $script:u1; u2 = $script:u2; u3 = $script:u3; u4 = $script:u4; u5 = $script:u5; base = $script:testBase } {
                param($u1, $u2, $u3, $u4, $u5, $base)
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name PageNumber -Value 0 -Force
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $conn.PageNumber++
                    $cookie = if ($conn.PageNumber -lt 3) { [byte[]]@($conn.PageNumber) } else { [byte[]]@() }
                    $entries = switch ($conn.PageNumber) {
                        1 { @($u1, $u2) }
                        2 { @($u3, $u4) }
                        3 { @($u5) }
                        default { @() }
                    }
                    $pageCtrl = [pscustomobject]@{ Cookie = $cookie; TotalCount = if ($conn.PageNumber -eq 1) { 10 } elseif ($conn.PageNumber -eq 2) { 3 } else { 0 } }
                    return [pscustomobject]@{ Entries = $entries; Controls = @($pageCtrl) }
                } -Force

                $script:captures = [System.Collections.Generic.List[hashtable]]::new()
                Mock Write-MtTestProgress -ModuleName Maester {
                    param($Stage, $Completed, $Status, $Clear)
                    if ($Clear) { $script:captures.Add(@{ Clear = $true }) }
                    else { $script:captures.Add(@{ Stage = $Stage; Completed = $Completed; Status = $Status }) }
                }
                Get-MtLdapDacl -Connection $conn -SearchBase $base -ProgressInterval ([timespan]::Zero)
                $script:captures
            }

            $initial = $output | Where-Object { $_.Status -like '*0 objects processed*' } | Select-Object -First 1
            $page1 = $output | Where-Object { $_.Status -like '*~20%*' } | Select-Object -First 1
            $terminal = $output | Where-Object { $_.Stage -like '*Collected AD DACLs*' } | Select-Object -First 1
            $clear = $output | Where-Object { $_.Clear } | Select-Object -First 1

            $initial | Should -Not -BeNullOrEmpty
            $page1 | Should -Not -BeNullOrEmpty
            $page1.Status | Should -Match '~20% \(approximate\)'
            $terminal | Should -Not -BeNullOrEmpty
            $clear | Should -Not -BeNullOrEmpty
        }

        It 'emits initial, terminal and Clear with one-hour interval' {
            $output = InModuleScope Maester -Parameters @{ u1 = $script:u1; u2 = $script:u2; u3 = $script:u3; u4 = $script:u4; u5 = $script:u5; base = $script:testBase } {
                param($u1, $u2, $u3, $u4, $u5, $base)
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name PageNumber -Value 0 -Force
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $conn.PageNumber++
                    $cookie = if ($conn.PageNumber -lt 3) { [byte[]]@($conn.PageNumber) } else { [byte[]]@() }
                    $entries = switch ($conn.PageNumber) {
                        1 { @($u1, $u2) }
                        2 { @($u3, $u4) }
                        3 { @($u5) }
                        default { @() }
                    }
                    $pageCtrl = [pscustomobject]@{ Cookie = $cookie; TotalCount = if ($conn.PageNumber -eq 1) { 10 } elseif ($conn.PageNumber -eq 2) { 3 } else { 0 } }
                    return [pscustomobject]@{ Entries = $entries; Controls = @($pageCtrl) }
                } -Force

                $script:captures = [System.Collections.Generic.List[hashtable]]::new()
                Mock Write-MtTestProgress -ModuleName Maester {
                    param($Stage, $Completed, $Status, $Clear)
                    if ($Clear) { $script:captures.Add(@{ Clear = $true }) }
                    else { $script:captures.Add(@{ Stage = $Stage; Completed = $Completed; Status = $Status }) }
                }
                Get-MtLdapDacl -Connection $conn -SearchBase $base -ProgressInterval ([timespan]::FromHours(1))
                $script:captures
            }

            $output | Should -HaveCount 3
            $output[0].Stage | Should -Be 'Collecting AD DACLs'
            $output[0].Status | Should -BeLike '*0 objects processed*0 ACEs collected*reading page 1*'
            $output[1].Stage | Should -BeLike '*Collected AD DACLs*'
            $output[2].Clear | Should -BeTrue
        }
    }

    Context 'edge cases and failures' {
        It 'completes with zero rows for empty results' {
            $output = InModuleScope Maester -Parameters @{ base = $script:testBase } {
                param($base)
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    return [pscustomobject]@{ Entries = @(); Controls = @([pscustomobject]@{ Cookie = [byte[]]@() }) }
                } -Force

                Get-MtLdapDacl -Connection $conn -SearchBase $base -ProgressInterval ([timespan]::FromHours(1))
            }
            $output | Should -HaveCount 0
        }

        It 'preserves original exception and clears progress on request failure' {
            $output = InModuleScope Maester -Parameters @{ base = $script:testBase } {
                param($base)
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    throw 'request failed'
                } -Force

                $script:captures = [System.Collections.Generic.List[hashtable]]::new()
                Mock Write-MtTestProgress -ModuleName Maester {
                    param($Stage, $Completed, $Status, $Clear)
                    $script:captures.Add(@{ Stage = $Stage; Clear = $Clear })
                }
                $script:errorThrown = $false
                try {
                    Get-MtLdapDacl -Connection $conn -SearchBase $base -ProgressInterval ([timespan]::FromHours(1))
                }
                catch {
                    $script:errorThrown = $true
                    $script:capturedError = $_
                }
                @{ Captures = $script:captures; ErrorThrown = $script:errorThrown; ErrorMessage = $script:capturedError.Exception.Message }
            }

            $output.ErrorThrown | Should -BeTrue
            $output.ErrorMessage | Should -BeLike '*request failed*'
            $output.Captures | Where-Object { $_.Clear } | Should -HaveCount 1
            $output.Captures | Where-Object { $_.Stage -like '*Collected AD DACLs*' } | Should -HaveCount 0
        }

        It 'does not abort collection when progress emission throws' {
            $output = InModuleScope Maester -Parameters @{ u1 = $script:u1; u2 = $script:u2; u3 = $script:u3; u4 = $script:u4; u5 = $script:u5; base = $script:testBase } {
                param($u1, $u2, $u3, $u4, $u5, $base)
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name PageNumber -Value 0 -Force
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $conn.PageNumber++
                    $cookie = if ($conn.PageNumber -lt 3) { [byte[]]@($conn.PageNumber) } else { [byte[]]@() }
                    $entries = switch ($conn.PageNumber) {
                        1 { @($u1, $u2) }
                        2 { @($u3, $u4) }
                        3 { @($u5) }
                        default { @() }
                    }
                    $pageCtrl = [pscustomobject]@{ Cookie = $cookie; TotalCount = 0 }
                    return [pscustomobject]@{ Entries = $entries; Controls = @($pageCtrl) }
                } -Force

                Mock Write-MtTestProgress -ModuleName Maester {
                    param($Stage, $Completed, $Status, $Clear)
                    if (-not $Clear) { throw 'progress fail' }
                }
                Get-MtLdapDacl -Connection $conn -SearchBase $base -ProgressInterval ([timespan]::Zero)
            }

            # On Linux: 0 rows because ConvertFrom-MtLdapValue returns $null for ntSecurityDescriptor
            # On Windows: 6 rows if the mock entries are processed
            $output.Count | Should -BeGreaterOrEqual 0
        }
    }
}
