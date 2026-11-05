# The readers of the defender's path measures (docs/proposals/defenders-path.md, section 11, and
# powershell/assets/MaesterMeasures.psd1): what each one reads from Graph, what it counts and which objects it lists.
BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
}

Describe 'The measure registry' {
    It 'Names a reader that exists for every measure, and has no problems' {
        InModuleScope Maester {
            $registry = Get-MtMeasureRegistry
            $registry.Problems | Should -BeNullOrEmpty
            $registry.Measures.Keys | Should -Be @('devices-compliant', 'mfa-registered')
            foreach ($measure in $registry.Measures.Values) {
                Get-Command -Name $measure.Function -CommandType Function | Should -Not -BeNullOrEmpty
            }
        }
    }
}

Describe 'Get-MtDeviceComplianceShare' {
    BeforeAll {
        $script:devices = @(
            [pscustomobject]@{ id = 'd1'; displayName = 'Compliant laptop'; approximateLastSignInDateTime = '2026-11-04T08:00:00Z'; isCompliant = $true; isManaged = $true }
            [pscustomobject]@{ id = 'd2'; displayName = 'Noncompliant laptop'; approximateLastSignInDateTime = '2026-10-20T08:00:00Z'; isCompliant = $false; isManaged = $true }
            [pscustomobject]@{ id = 'd3'; displayName = 'Personal phone'; approximateLastSignInDateTime = '2026-11-03T08:00:00Z'; isCompliant = $null; isManaged = $false }
            [pscustomobject]@{ id = 'd4'; displayName = 'Compliant phone'; approximateLastSignInDateTime = '2026-11-01T08:00:00Z'; isCompliant = $true; isManaged = $true }
        )
    }

    It 'Counts the compliant devices and lists the others, most recent sign-in first' {
        InModuleScope Maester -Parameters @{ Devices = $script:devices } {
            Mock Invoke-MtGraphRequest { $Devices } -ParameterFilter { $RelativeUri -eq 'devices' }

            $result = Get-MtDeviceComplianceShare

            $result.Count | Should -Be 2
            $result.Total | Should -Be 4
            $result.Objects.Id | Should -Be @('d3', 'd2')
            $result.Objects[0].Type | Should -Be 'Device'
            $result.Objects[0].DisplayName | Should -Be 'Personal phone'
            $result.Objects[0].PSObject.Properties.Name | Should -Be @('Type', 'Id', 'DisplayName')
        }
    }

    It 'Reads the enabled devices that signed in since the start of the UTC day, SignedInWithinDays ago' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest { }
            $since = [datetime]::UtcNow.Date.AddDays(-14).ToString('yyyy-MM-ddTHH:mm:ssZ', [cultureinfo]::InvariantCulture)

            $null = Get-MtDeviceComplianceShare -SignedInWithinDays 14

            Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                $RelativeUri -eq 'devices' -and
                $Filter -eq "accountEnabled eq true and approximateLastSignInDateTime ge $since" -and
                $Select -contains 'isCompliant' -and $Select -contains 'isManaged' -and
                $QueryParameters['$count'] -eq 'true' -and -not $DisableCache
            }
        }
    }

    It 'Returns zero of zero when no device signed in' {
        InModuleScope Maester {
            Mock Invoke-MtGraphRequest { }

            $result = Get-MtDeviceComplianceShare

            $result.Count | Should -Be 0
            $result.Total | Should -Be 0
            @($result.Objects).Count | Should -Be 0
        }
    }
}

Describe 'Get-MtMfaRegistrationShare' {
    BeforeAll {
        $script:report = @(
            [pscustomobject]@{ id = 'u1'; userPrincipalName = 'ann@contoso.com'; userDisplayName = 'Ann'; userType = 'member'; isMfaRegistered = $true; isAdmin = $false }
            [pscustomobject]@{ id = 'u2'; userPrincipalName = 'bob@contoso.com'; userDisplayName = 'Bob'; userType = 'member'; isMfaRegistered = $false; isAdmin = $false }
            [pscustomobject]@{ id = 'u3'; userPrincipalName = 'admin@contoso.com'; userDisplayName = 'Admin'; userType = 'member'; isMfaRegistered = $false; isAdmin = $true }
            [pscustomobject]@{ id = 'g1'; userPrincipalName = 'guest#EXT#@contoso.com'; userDisplayName = 'Guest'; userType = 'guest'; isMfaRegistered = $false; isAdmin = $false }
            [pscustomobject]@{ id = 'x1'; userPrincipalName = 'left@contoso.com'; userDisplayName = 'Left'; userType = 'member'; isMfaRegistered = $false; isAdmin = $false }
            [pscustomobject]@{ id = 'bg1'; userPrincipalName = 'bg1@contoso.com'; userDisplayName = 'Break glass 1'; userType = 'member'; isMfaRegistered = $false; isAdmin = $true }
            [pscustomobject]@{ id = 'bg2'; userPrincipalName = 'bg2@contoso.com'; userDisplayName = 'Break glass 2'; userType = 'member'; isMfaRegistered = $false; isAdmin = $true }
            [pscustomobject]@{ id = 's1'; userPrincipalName = 'Sync_SRV@contoso.onmicrosoft.com'; userDisplayName = 'On-Premises Directory Synchronization Service Account'; userType = 'member'; isMfaRegistered = $false; isAdmin = $false }
            [pscustomobject]@{ id = 'u4'; userPrincipalName = 'cat@contoso.com'; userDisplayName = 'Cat'; userType = 'member'; isMfaRegistered = $true; isAdmin = $false }
        )
    }

    Context 'With emergency access accounts and a sync account' {
        BeforeEach {
            # Defined outside InModuleScope, so the mock bodies can read the report from this file's scope.
            Mock -ModuleName Maester Invoke-MtGraphRequest { $script:report } -ParameterFilter { $RelativeUri -eq 'reports/authenticationMethods/userRegistrationDetails' }
            Mock -ModuleName Maester Invoke-MtGraphRequest { @([pscustomobject]@{ id = 'x1' }) } -ParameterFilter { $RelativeUri -eq 'users' }
            Mock -ModuleName Maester Get-MtEmergencyAccessAccount {
                [pscustomobject]@{ ObjectId = 'bg1'; DisplayName = 'Break glass 1'; Type = 'user' }
                [pscustomobject]@{ ObjectId = '7c2c5a3e-0d4b-4f7a-9a51-2f0c8e6d1b11'; DisplayName = 'Break glass group'; Type = 'group' }
            }
            Mock -ModuleName Maester Get-MtGroupMember {
                [pscustomobject]@{ id = 'bg2'; '@odata.type' = '#microsoft.graph.user' }
                [pscustomobject]@{ id = 'nested'; '@odata.type' = '#microsoft.graph.group' }
            } -ParameterFilter { $GroupId -eq '7c2c5a3e-0d4b-4f7a-9a51-2f0c8e6d1b11' -and $Recursive }
            Mock -ModuleName Maester Get-MtRoleMember {
                [pscustomobject]@{ id = 's1'; '@odata.type' = '#microsoft.graph.user' }
                [pscustomobject]@{ id = 'u1'; '@odata.type' = '#microsoft.graph.servicePrincipal' }
            }
        }

        It 'Counts the registered member users, leaving out guests, disabled, emergency access and sync accounts' {
            InModuleScope Maester {
                $result = Get-MtMfaRegistrationShare

                $result.Count | Should -Be 2
                $result.Total | Should -Be 4
            }
        }

        It 'Lists the users who are not registered, administrators first' {
            InModuleScope Maester {
                $result = Get-MtMfaRegistrationShare

                $result.Objects.Id | Should -Be @('u3', 'u2')
                $result.Objects[0].Type | Should -Be 'User'
                $result.Objects[0].DisplayName | Should -Be 'Admin'
                $result.Objects[0].PSObject.Properties.Name | Should -Be @('Type', 'Id', 'DisplayName')
            }
        }

        It 'Reads the whole report, so other readers share its cache entry, and only the disabled users' {
            InModuleScope Maester {
                $null = Get-MtMfaRegistrationShare

                Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $RelativeUri -eq 'reports/authenticationMethods/userRegistrationDetails' -and -not $Select -and -not $Filter -and -not $DisableCache
                }
                Should -Invoke Invoke-MtGraphRequest -Times 1 -Exactly -ParameterFilter {
                    $RelativeUri -eq 'users' -and $Filter -eq 'accountEnabled eq false' -and -not $DisableCache
                }
                Should -Invoke Get-MtRoleMember -Times 1 -Exactly -ParameterFilter {
                    ($Role -join ',') -eq 'DirectorySynchronizationAccounts,OnPremisesDirectorySyncAccount'
                }
            }
        }
    }

    It 'Counts every enabled member user when no emergency access account is configured' {
        InModuleScope Maester -Parameters @{ Report = $script:report } {
            Mock Invoke-MtGraphRequest { $Report } -ParameterFilter { $RelativeUri -eq 'reports/authenticationMethods/userRegistrationDetails' }
            Mock Invoke-MtGraphRequest { } -ParameterFilter { $RelativeUri -eq 'users' }
            Mock Get-MtEmergencyAccessAccount { }
            Mock Get-MtGroupMember { }
            Mock Get-MtRoleMember { }

            $result = Get-MtMfaRegistrationShare

            $result.Count | Should -Be 2
            $result.Total | Should -Be 8
            Should -Invoke Get-MtGroupMember -Times 0
        }
    }

    It 'Stops when a configured emergency access account cannot be resolved' {
        InModuleScope Maester -Parameters @{ Report = $script:report } {
            Mock Invoke-MtGraphRequest { $Report } -ParameterFilter { $RelativeUri -eq 'reports/authenticationMethods/userRegistrationDetails' }
            Mock Invoke-MtGraphRequest { } -ParameterFilter { $RelativeUri -eq 'users' }
            Mock Get-MtEmergencyAccessAccount { throw 'Could not resolve configured emergency access object(s): user: gone@contoso.com (not found)' }
            Mock Get-MtRoleMember { }

            { Get-MtMfaRegistrationShare } | Should -Throw '*Could not resolve configured emergency access*'
        }
    }
}
