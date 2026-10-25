#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

Describe 'Invoke-MtLdapSearch paging callback' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -ErrorAction Stop
    }

    InModuleScope Maester {
        Context 'default mode (no ProcessPage)' {
            It 'returns all entries when ProcessPage is not supplied' {
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $entries = @(
                        [pscustomobject]@{ DistinguishedName = 'CN=User1'; Attributes = [pscustomobject]@{ } }
                    )
                    return [pscustomobject]@{
                        Entries = $entries
                        Controls = @()
                    }
                } -Force

                $result = Invoke-MtLdapSearch -Connection $conn -SearchBase 'DC=contoso,DC=com' -PageSize 0
                $result | Should -HaveCount 1
                $result[0].DistinguishedName | Should -Be 'CN=User1'
            }
        }

        Context 'ProcessPage callback' {
            It 'invokes ProcessPage once per page and returns nothing' {
                $pages = [System.Collections.Generic.List[object]]::new()
                $call = 0
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $call++
                    $cookie = if ($call -lt 2) { [byte[]]@(1) } else { [byte[]]@() }
                    $entries = @(
                        [pscustomobject]@{ DistinguishedName = "CN=User$call"; Attributes = [pscustomobject]@{ } }
                    )
                    $pageCtrl = [pscustomobject]@{
                        Cookie = $cookie
                        TotalCount = 10
                    }
                    return [pscustomobject]@{
                        Entries = $entries
                        Controls = @($pageCtrl)
                    }
                } -Force

                $state = @{ Counter = 0 }
                $result = Invoke-MtLdapSearch -Connection $conn -SearchBase 'DC=contoso,DC=com' -PageSize 1 -ProcessPage {
                    param($page, $s)
                    $pages.Add($page)
                    $s.Counter++
                } -PageState $state

                $result | Should -BeNullOrEmpty
                $pages | Should -HaveCount 2
                $pages[0].PageNumber | Should -Be 1
                $pages[0].ObjectsRead | Should -Be 1
                $pages[0].EstimatedTotal | Should -Be 10
                $pages[0].HasMore | Should -BeTrue
                $pages[1].PageNumber | Should -Be 2
                $pages[1].ObjectsRead | Should -Be 2
                $pages[1].HasMore | Should -BeFalse
                $state.Counter | Should -Be 2
            }

            It 'passes zero EstimatedTotal when server estimate is unavailable' {
                $pages = [System.Collections.Generic.List[object]]::new()
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $entries = @(
                        [pscustomobject]@{ DistinguishedName = 'CN=A'; Attributes = [pscustomobject]@{ } }
                    )
                    $pageCtrl = [pscustomobject]@{
                        Cookie = [byte[]]@()
                    }
                    return [pscustomobject]@{
                        Entries = $entries
                        Controls = @($pageCtrl)
                    }
                } -Force

                Invoke-MtLdapSearch -Connection $conn -SearchBase 'DC=contoso,DC=com' -PageSize 1 -ProcessPage {
                    param($page, $s)
                    $pages.Add($page)
                } | Out-Null

                $pages[0].EstimatedTotal | Should -Be 0
            }

            It 'does not include converted entries in return value when ProcessPage is supplied' {
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $entries = @(
                        [pscustomobject]@{ DistinguishedName = 'CN=X'; Attributes = [pscustomobject]@{ } }
                    )
                    return [pscustomobject]@{
                        Entries = $entries
                        Controls = @()
                    }
                } -Force

                $result = Invoke-MtLdapSearch -Connection $conn -SearchBase 'DC=contoso,DC=com' -PageSize 0 -ProcessPage { param($p, $s) } -PageState $null
                $result | Should -BeNullOrEmpty
            }

            It 'does not leak callback exceptions into SendRequest error wrapping' {
                $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
                $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                    param($req, $to)
                    $entries = @(
                        [pscustomobject]@{ DistinguishedName = 'CN=Y'; Attributes = [pscustomobject]@{ } }
                    )
                    return [pscustomobject]@{
                        Entries = $entries
                        Controls = @()
                    }
                } -Force

                $errorThrown = $false
                try {
                    Invoke-MtLdapSearch -Connection $conn -SearchBase 'DC=contoso,DC=com' -PageSize 0 -ProcessPage {
                        param($p, $s)
                        throw 'callback error'
                    } -PageState $null
                }
                catch {
                    $errorThrown = $true
                    $_.Exception.Message | Should -BeLike '*callback error*'
                }
                $errorThrown | Should -BeTrue
            }
        }
    }
}
