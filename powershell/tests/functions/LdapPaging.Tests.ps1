#Requires -Modules @{ ModuleName='Pester'; ModuleVersion='5.0.0' }

Describe 'Invoke-MtLdapSearch paging callback' {
    BeforeAll {
        Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -ErrorAction Stop
        $script:MaesterModule = Get-Module Maester
    }

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

            $result = $script:MaesterModule.Invoke({ param($c) Invoke-MtLdapSearch -Connection $c -SearchBase 'DC=contoso,DC=com' -PageSize 0 }, $conn)
            $result | Should -HaveCount 1
            $result[0].DistinguishedName | Should -Be 'CN=User1'
        }
    }

    Context 'ProcessPage callback' {
        It 'invokes ProcessPage once per page and returns nothing' {
            $call = 0
            $conn = [System.DirectoryServices.Protocols.LdapConnection]::new('ldap.mock')
            $conn | Add-Member -MemberType NoteProperty -Name MtSendRequestOverride -Value {
                param($req, $to)
                $script:call++
                $cookie = if ($script:call -lt 2) { [byte[]]@(1) } else { [byte[]]@() }
                $entries = @(
                    [pscustomobject]@{ DistinguishedName = "CN=User$script:call"; Attributes = [pscustomobject]@{ } }
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

            $state = @{ Counter = 0; Pages = [System.Collections.Generic.List[object]]::new() }
            $cb = {
                param($page, $s)
                $s.Pages.Add($page)
                $s.Counter++
            }
            $result = $script:MaesterModule.Invoke({ param($c, $p, $s) Invoke-MtLdapSearch -Connection $c -SearchBase 'DC=contoso,DC=com' -PageSize 1 -ProcessPage $p -PageState $s }, @($conn, $cb, $state))

            $result | Should -BeNullOrEmpty
            $state.Pages | Should -HaveCount 2
            $state.Pages[0].PageNumber | Should -Be 1
            $state.Pages[0].ObjectsRead | Should -Be 1
            $state.Pages[0].EstimatedTotal | Should -Be 10
            $state.Pages[0].HasMore | Should -BeTrue
            $state.Pages[1].PageNumber | Should -Be 2
            $state.Pages[1].ObjectsRead | Should -Be 2
            $state.Pages[1].HasMore | Should -BeFalse
            $state.Counter | Should -Be 2
        }

        It 'passes zero EstimatedTotal when server estimate is unavailable' {
            $state = @{ Pages = [System.Collections.Generic.List[object]]::new() }
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

            $cb = {
                param($page, $s)
                $script:testPages.Add($page)
            }
            $script:testPages = [System.Collections.Generic.List[object]]::new()
            $null = $script:MaesterModule.Invoke({ param($c, $p) Invoke-MtLdapSearch -Connection $c -SearchBase 'DC=contoso,DC=com' -PageSize 1 -ProcessPage $p -PageState $null }, @($conn, $cb))

            $script:testPages[0].EstimatedTotal | Should -Be 0
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

            $cb = { param($p, $s) }
            $result = $script:MaesterModule.Invoke({ param($c, $p) Invoke-MtLdapSearch -Connection $c -SearchBase 'DC=contoso,DC=com' -PageSize 0 -ProcessPage $p -PageState $null }, $conn, $cb)
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

            $cb = {
                param($p, $s)
                throw 'callback error'
            }
            $caught = $null
            try {
                $script:MaesterModule.Invoke({ param($c, $p) Invoke-MtLdapSearch -Connection $c -SearchBase 'DC=contoso,DC=com' -PageSize 0 -ProcessPage $p -PageState $null }, $conn, $cb)
            }
            catch {
                $caught = $_
            }
            $caught | Should -Not -BeNullOrEmpty
            $caught.Exception.Message | Should -BeLike '*callback error*'
            $caught.Exception.Message | Should -Not -BeLike '*LDAP search failed*'
        }
    }
}
