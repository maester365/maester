BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force
}

Describe 'Sensitive settings in result configuration' {
    BeforeEach {
        InModuleScope Maester {
            $script:savedSettingsRegistry = $script:__MtSettingsRegistry
            $script:__MtSettingsRegistry = Import-PowerShellDataFile (Join-Path $ExecutionContext.SessionState.Module.ModuleBase 'assets/MaesterSettings.psd1')
            $script:__MtSettingsRegistry.Settings.FixtureSensitive = @{ Type = 'object'; Default = @{}; Sensitive = $true; Description = 'Synthetic sensitive setting.' }
        }
        $script:config = [pscustomobject]@{
            GlobalSettings = [pscustomobject]@{
                FixtureSensitive = [pscustomobject]@{
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
    AfterEach { InModuleScope Maester { $__MtSession.MaesterConfig = $null; $script:__MtSettingsRegistry = $script:savedSettingsRegistry } }

    It 'Redacts the whole policy, preserves public settings and does not mutate input (native=<Native>)' -ForEach @(@{ Native = $true }, @{ Native = $false }) {
        $before = $script:config | ConvertTo-Json -Depth 30 -Compress
        $out = InModuleScope Maester -Parameters @{ Config = $script:config; Native = $Native } {
            $nativeRows = if ($Native) { @([pscustomobject]@{ Id = 'CIS.GH.1.2.3' }) } else { @() }
            New-MtResultConfig -RunConfig $Config -NativeRows $nativeRows -Rows @([pscustomobject]@{ Id = 'CIS.GH.1.2.3'; Title = 'Fixture'; Severity = 'Low' })
        }
        $out.GlobalSettings.FixtureSensitive | Should -Be '<redacted>'
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
                $out.GlobalSettings.FixtureSensitive.OrganizationId | Should -Be '123456789'
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
            $content | Should -Match 'FixtureSensitive'
            $content | Should -Match 'redacted'
        }
        ((Get-Content $jsonPath -Raw | ConvertFrom-Json).MaesterConfig.GlobalSettings.FixtureSensitive) | Should -Be '<redacted>'
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
            $content | Should -Match 'FixtureSensitive'
            $content | Should -Match 'redacted'
        }
        $script:config.GlobalSettings.FixtureSensitive.ApprovedOwnerIds.Count | Should -Be 2
    }
}
