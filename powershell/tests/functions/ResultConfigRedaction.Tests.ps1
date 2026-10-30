BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Sensitive settings in exported result configuration' {
    BeforeEach {
        $script:config = [pscustomobject]@{
            GlobalSettings = [pscustomobject]@{
                GitHubEnterprise = 'fixture-private-enterprise'
                GitHubCisRepositoryScope = [pscustomobject]@{ Organization = 'fixture-org'; Complete = $true; Repositories = @([pscustomobject]@{ Id = 101; InUse = $false; ExclusionReason = 'fixture-private-exclusion' }) }
                GitHubOrganization = 'fixture-org'
                'Pack.Public' = [pscustomobject]@{ Values = @('one', 'two') }
            }
            TestSettings = @([pscustomobject]@{ Id = 'CIS.GH.1.1.9'; Severity = 'Low' })
            TestSettingsHash = @{}
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.MaesterConfig = $null } }

    It 'Redacts whole registered values, detaches nested config and preserves settings contracts (native=<Native>)' -ForEach @(@{ Native = $true }, @{ Native = $false }) {
        $out = InModuleScope Maester -Parameters @{ Config = $script:config; Native = $Native } {
            $nativeRows = if ($Native) { @([pscustomobject]@{ Id = 'CIS.GH.1.1.9' }) } else { @() }
            New-MtResultConfig -RunConfig $Config -NativeRows $nativeRows -Rows @([pscustomobject]@{ Id = 'CIS.GH.1.1.9'; Title = 'Fixture'; Severity = 'Low' })
        }
        $out.GlobalSettings.GitHubEnterprise | Should -Be '<redacted>'
        $out.GlobalSettings.GitHubCisRepositoryScope | Should -Be '<redacted>'
        $out.GlobalSettings.GitHubOrganization | Should -Be 'fixture-org'
        $out.TestSettings[0].Severity | Should -Be 'Low'
        $out.GlobalSettings.'Pack.Public'.Values[0] = 'changed'
        $script:config.GlobalSettings.'Pack.Public'.Values[0] | Should -Be 'one'
        $script:config.GlobalSettings.GitHubEnterprise | Should -Be 'fixture-private-enterprise'
        $script:config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].ExclusionReason | Should -Be 'fixture-private-exclusion'
    }

    It 'Uses the registry rather than a hard-coded list' {
        InModuleScope Maester -Parameters @{ Config = $script:config } {
            $saved = $script:__MtSettingsRegistry
            try {
                $script:__MtSettingsRegistry = @{ Settings = @{ GitHubOrganization = @{ Sensitive = $true } } }
                $out = New-MtResultConfig -RunConfig $Config
                $out.GlobalSettings.GitHubOrganization | Should -Be '<redacted>'
                $out.GlobalSettings.GitHubEnterprise | Should -Be 'fixture-private-enterprise'
                $Config.GlobalSettings.GitHubOrganization | Should -Be 'fixture-org'
            } finally { $script:__MtSettingsRegistry = $saved }
        }
    }

    It 'Exports JSON and embedded HTML data without unused/excluded sensitive configuration for an unexecuted GitHub check' {
        $jsonPath = Join-Path $TestDrive 'skipped.json'
        $htmlPath = Join-Path $TestDrive 'skipped.html'
        $before = $script:config | ConvertTo-Json -Depth 30 -Compress
        $result = Invoke-Maester -Config $script:config -TestId CIS.GH.1.1.9 -DryRun -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputJsonFile $jsonPath -OutputHtmlFile $htmlPath
        $rows = @($result.Tests | Where-Object Id -EQ 'CIS.GH.1.1.9')
        $rows.Count | Should -Be 1
        $rows[0].Result | Should -Be 'Skipped'
        $rows[0].ReasonCode | Should -Be 'ServiceNotConnected'
        $json = Get-Content $jsonPath -Raw
        $html = Get-Content $htmlPath -Raw
        foreach ($content in $json, $html) {
            $content | Should -Not -Match 'fixture-private-enterprise|fixture-private-exclusion'
            $content | Should -Match 'GitHubCisRepositoryScope'
            $content | Should -Match 'redacted'
        }
        ($json | ConvertFrom-Json).MaesterConfig.GlobalSettings.GitHubCisRepositoryScope | Should -Be '<redacted>'
        $html | Should -Match '"GitHubCisRepositoryScope":"\\u003credacted\\u003e"'
        ($script:config | ConvertTo-Json -Depth 30 -Compress) | Should -Be $before
        InModuleScope Maester {
            (Get-MtSetting GitHubCisRepositoryScope).Repositories[0].ExclusionReason | Should -Be 'fixture-private-exclusion'
        }
    }

    It 'Redacts the zero-native-result conversion path in actual JSON and HTML artifacts' {
        $result = InModuleScope Maester -Parameters @{ Config = $script:config } {
            $__MtSession.MaesterConfig = $Config
            ConvertTo-MtMaesterResult -SkipVersionCheck
        }
        $result.TotalCount | Should -Be 0
        $jsonPath = Join-Path $TestDrive 'empty.json'
        $htmlPath = Join-Path $TestDrive 'empty.html'
        $result | ConvertTo-Json -Depth 30 | Set-Content $jsonPath
        Get-MtHtmlReport -MaesterResults $result | Set-Content $htmlPath
        foreach ($path in $jsonPath, $htmlPath) {
            $content = Get-Content $path -Raw
            $content | Should -Not -Match 'fixture-private-enterprise|fixture-private-exclusion'
            $content | Should -Match 'GitHubEnterprise'
            $content | Should -Match 'redacted'
        }
        $script:config.GlobalSettings.GitHubCisRepositoryScope.Repositories[0].InUse | Should -BeFalse
    }
}

Describe 'Sensitive GitHub deletion policy in result configuration' {
    BeforeEach {
        $script:config = [pscustomobject]@{
            GlobalSettings = [pscustomobject]@{
                GitHubDeletionPolicy = [pscustomobject]@{
                    ApiBaseUri = 'https://api.fixture-private.ghe.com'
                    OrganizationId = '123456789'
                    ApprovedOwnerIds = @('234567891', '345678912')
                    Repositories = @([pscustomobject]@{ Id = '456789123'; ApprovedAdministratorIds = @('234567891') })
                }
                GitHubOrganization = 'fixture-org'
                'Pack.Public' = [pscustomobject]@{ Values = @('one', 'two') }
            }
            TestSettings = @([pscustomobject]@{ Id = 'CIS.GH.1.2.3'; Severity = 'Low' })
            TestSettingsHash = @{}
        }
    }
    AfterEach { InModuleScope Maester { $__MtSession.MaesterConfig = $null } }

    It 'Redacts the whole policy, preserves public settings and does not mutate input (native=<Native>)' -ForEach @(@{ Native = $true }, @{ Native = $false }) {
        $before = $script:config | ConvertTo-Json -Depth 30 -Compress
        $out = InModuleScope Maester -Parameters @{ Config = $script:config; Native = $Native } {
            $nativeRows = if ($Native) { @([pscustomobject]@{ Id = 'CIS.GH.1.2.3' }) } else { @() }
            New-MtResultConfig -RunConfig $Config -NativeRows $nativeRows -Rows @([pscustomobject]@{ Id = 'CIS.GH.1.2.3'; Title = 'Fixture'; Severity = 'Low' })
        }
        $out.GlobalSettings.GitHubDeletionPolicy | Should -Be '<redacted>'
        $out.GlobalSettings.GitHubOrganization | Should -Be 'fixture-org'
        $out.TestSettings[0].Severity | Should -Be 'Low'
        $out.GlobalSettings.'Pack.Public'.Values[0] = 'changed'
        ($script:config | ConvertTo-Json -Depth 30 -Compress) | Should -Be $before
    }

    It 'Uses registry sensitivity rather than a hard-coded setting name' {
        InModuleScope Maester -Parameters @{ Config = $script:config } {
            $saved = $script:__MtSettingsRegistry
            try {
                $script:__MtSettingsRegistry = @{ Settings = @{ GitHubOrganization = @{ Sensitive = $true } } }
                $out = New-MtResultConfig -RunConfig $Config
                $out.GlobalSettings.GitHubOrganization | Should -Be '<redacted>'
                $out.GlobalSettings.GitHubDeletionPolicy.OrganizationId | Should -Be '123456789'
                $Config.GlobalSettings.GitHubOrganization | Should -Be 'fixture-org'
            } finally { $script:__MtSettingsRegistry = $saved }
        }
    }

    It 'Redacts unused approval identities in actual JSON and embedded HTML for a disconnected check' {
        $jsonPath = Join-Path $TestDrive 'skipped.json'
        $htmlPath = Join-Path $TestDrive 'skipped.html'
        $before = $script:config | ConvertTo-Json -Depth 30 -Compress
        $result = Invoke-Maester -Config $script:config -TestId CIS.GH.1.2.3 -DryRun -PassThru -SkipGraphConnect -NonInteractive -DisableTelemetry -SkipVersionCheck -NoLogo -OutputJsonFile $jsonPath -OutputHtmlFile $htmlPath
        $row = @($result.Tests | Where-Object Id -EQ 'CIS.GH.1.2.3')
        $row.Count | Should -Be 1
        $row[0].Result | Should -Be 'Skipped'
        $row[0].ReasonCode | Should -Be 'ServiceNotConnected'
        foreach ($path in $jsonPath, $htmlPath) {
            $content = Get-Content $path -Raw
            $content | Should -Not -Match 'fixture-private|123456789|234567891|345678912|456789123'
            $content | Should -Match 'GitHubDeletionPolicy'
            $content | Should -Match 'redacted'
        }
        ((Get-Content $jsonPath -Raw | ConvertFrom-Json).MaesterConfig.GlobalSettings.GitHubDeletionPolicy) | Should -Be '<redacted>'
        ($script:config | ConvertTo-Json -Depth 30 -Compress) | Should -Be $before
    }

    It 'Redacts the zero-native-result conversion path in actual JSON and HTML' {
        $result = InModuleScope Maester -Parameters @{ Config = $script:config } {
            $__MtSession.MaesterConfig = $Config
            ConvertTo-MtMaesterResult -SkipVersionCheck
        }
        $result.TotalCount | Should -Be 0
        $json = $result | ConvertTo-Json -Depth 30
        $html = Get-MtHtmlReport -MaesterResults $result
        foreach ($content in $json, $html) {
            $content | Should -Not -Match 'fixture-private|123456789|234567891|345678912|456789123'
            $content | Should -Match 'GitHubDeletionPolicy'
            $content | Should -Match 'redacted'
        }
        $script:config.GlobalSettings.GitHubDeletionPolicy.ApprovedOwnerIds.Count | Should -Be 2
    }
}
