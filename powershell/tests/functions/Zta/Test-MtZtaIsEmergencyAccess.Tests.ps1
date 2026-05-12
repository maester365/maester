# Unit tests for Test-MtZtaIsEmergencyAccess + Get-MtZta -Section EmergencyAccessAccounts.
# Covers all three input shapes (string UPN, string GUID, object) plus negative cases.

Describe 'Test-MtZtaIsEmergencyAccess' -Tag 'Acceptance', 'Zta', 'Unit' {

    BeforeAll {
        Remove-Module Maester -ErrorAction Ignore
        Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
        $script:mod = Get-Module Maester
        $script:fixtureDir = Join-Path $PSScriptRoot 'fixtures'
    }

    BeforeEach {
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
        $script:bundle = Join-Path ([System.IO.Path]::GetTempPath()) ("mt-zta-bg-$([guid]::NewGuid())")
        New-Item -ItemType Directory -Force -Path $script:bundle | Out-Null
        Copy-Item (Join-Path $script:fixtureDir 'ZeroTrustAssessmentReport.sample.json') (Join-Path $script:bundle 'ZeroTrustAssessmentReport.json')
        Copy-Item (Join-Path $script:fixtureDir 'manifest.sample.json') (Join-Path $script:bundle 'manifest.json')
    }

    AfterEach {
        if ($script:bundle -and (Test-Path $script:bundle)) { Remove-Item -Recurse -Force $script:bundle }
        & $script:mod { Set-Variable -Name 'MtZtaContext' -Value $null -Scope Script -Force }
    }

    Context 'No GlobalSettings supplied' {
        It 'returns $false on any input when GlobalSettings is absent' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            (Test-MtZtaIsEmergencyAccess -Id 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa') | Should -BeFalse
            (Test-MtZtaIsEmergencyAccess -UserPrincipalName 'someone@example.com') | Should -BeFalse
        }

        It 'Get-MtZta -Section EmergencyAccessAccounts returns empty array' {
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback
            $list = @(Get-MtZta -Section EmergencyAccessAccounts)
            $list.Count | Should -Be 0
        }
    }

    Context 'GlobalSettings with mixed input shapes' {
        BeforeEach {
            $gs = [pscustomobject]@{
                EmergencyAccessAccounts = @(
                    'breakglass1@contoso.onmicrosoft.com',
                    '11111111-2222-3333-4444-555555555555',
                    [pscustomobject]@{
                        userPrincipalName = 'breakglass2@contoso.onmicrosoft.com'
                        displayName = 'Tier-0 emergency #2'
                    },
                    [pscustomobject]@{
                        id = '99999999-aaaa-bbbb-cccc-dddddddddddd'
                        userPrincipalName = 'breakglass3@contoso.onmicrosoft.com'
                    }
                )
            }
            Import-MtZtaResult -ZtaResultsPath $script:bundle -ForceJsonFallback -GlobalSettings $gs
        }

        It 'normalises UPN-shaped strings into UserPrincipalName entries' {
            $list = @(Get-MtZta -Section EmergencyAccessAccounts)
            $list.Count | Should -Be 4
            ($list | Where-Object { $_.UserPrincipalName -eq 'breakglass1@contoso.onmicrosoft.com' }).Id | Should -BeNullOrEmpty
        }

        It 'normalises GUID-shaped strings into Id entries' {
            $list = @(Get-MtZta -Section EmergencyAccessAccounts)
            $entry = $list | Where-Object { $_.Id -eq '11111111-2222-3333-4444-555555555555' }
            $entry | Should -Not -BeNullOrEmpty
            $entry.UserPrincipalName | Should -BeNullOrEmpty
        }

        It 'normalises object entries with both id and userPrincipalName' {
            $list = @(Get-MtZta -Section EmergencyAccessAccounts)
            $entry = $list | Where-Object { $_.Id -eq '99999999-aaaa-bbbb-cccc-dddddddddddd' }
            $entry.UserPrincipalName | Should -Be 'breakglass3@contoso.onmicrosoft.com'
        }

        It 'matches break-glass by Id (UPN unset on entry)' {
            (Test-MtZtaIsEmergencyAccess -Id '11111111-2222-3333-4444-555555555555') | Should -BeTrue
        }

        It 'matches break-glass by UPN (Id unset on entry)' {
            (Test-MtZtaIsEmergencyAccess -UserPrincipalName 'breakglass1@contoso.onmicrosoft.com') | Should -BeTrue
        }

        It 'UPN match is case-insensitive' {
            (Test-MtZtaIsEmergencyAccess -UserPrincipalName 'BREAKGLASS1@contoso.onmicrosoft.com') | Should -BeTrue
        }

        It 'matches when either Id or UPN matches an object-shaped entry' {
            (Test-MtZtaIsEmergencyAccess -Id '99999999-aaaa-bbbb-cccc-dddddddddddd' -UserPrincipalName 'unrelated@example.com') | Should -BeTrue
            (Test-MtZtaIsEmergencyAccess -Id 'random' -UserPrincipalName 'breakglass3@contoso.onmicrosoft.com') | Should -BeTrue
        }

        It 'returns $false for unknown principals' {
            (Test-MtZtaIsEmergencyAccess -Id 'ffffffff-ffff-ffff-ffff-ffffffffffff') | Should -BeFalse
            (Test-MtZtaIsEmergencyAccess -UserPrincipalName 'someone-else@example.com') | Should -BeFalse
        }

        It 'returns $false when both Id and UPN are empty' {
            (Test-MtZtaIsEmergencyAccess) | Should -BeFalse
            (Test-MtZtaIsEmergencyAccess -Id '' -UserPrincipalName '') | Should -BeFalse
        }
    }

    Context 'No context loaded' {
        It 'returns $false safely when MtZtaContext is null' {
            (Test-MtZtaIsEmergencyAccess -UserPrincipalName 'any@example.com') | Should -BeFalse
        }
    }
}
