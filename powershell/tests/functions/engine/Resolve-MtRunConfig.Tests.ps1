BeforeAll {
    Import-Module "$PSScriptRoot/../../../Maester.psd1" -Force
}

Describe 'Merge-MtConfigLayer' {
    It 'Merges GlobalSettings per key' {
        InModuleScope Maester {
            $base = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ A = 1; B = 2 } }
            $over = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ B = 3; C = 4 } }
            $m = Merge-MtConfigLayer -Base $base -Overlay $over
            $m.GlobalSettings.A | Should -Be 1
            $m.GlobalSettings.B | Should -Be 3
            $m.GlobalSettings.C | Should -Be 4
        }
    }

    It 'Merges TestSettings per Id and per property, case-insensitively' {
        InModuleScope Maester {
            $base = [pscustomobject]@{ TestSettings = @([pscustomobject]@{ Id = 'MT.1001'; Severity = 'High'; Title = 't' }) }
            $over = [pscustomobject]@{ TestSettings = @([pscustomobject]@{ Id = 'mt.1001'; Enabled = $false }, [pscustomobject]@{ Id = 'MT.2000'; Severity = 'Low' }) }
            $m = Merge-MtConfigLayer -Base $base -Overlay $over
            $m.TestSettings.Count | Should -Be 2
            $row = $m.TestSettings | Where-Object Id -EQ 'MT.1001'
            $row.Severity | Should -Be 'High'
            $row.Enabled | Should -BeFalse
            $row.Title | Should -Be 't'
        }
    }

    It 'Replaces arrays, so an empty array clears the lower layer' {
        InModuleScope Maester {
            $base = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ EmergencyAccessAccounts = @('a', 'b') } }
            $over = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ EmergencyAccessAccounts = @() } }
            (Merge-MtConfigLayer -Base $base -Overlay $over).GlobalSettings.EmergencyAccessAccounts.Count | Should -Be 0
        }
    }

    It 'Does not change the lower layer' {
        InModuleScope Maester {
            $base = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ A = 1 }; TestSettings = @([pscustomobject]@{ Id = 'X.1'; Severity = 'High' }) }
            $over = [pscustomobject]@{ GlobalSettings = [pscustomobject]@{ A = 2 }; TestSettings = @([pscustomobject]@{ Id = 'X.1'; Severity = 'Low' }) }
            $null = Merge-MtConfigLayer -Base $base -Overlay $over
            $base.GlobalSettings.A | Should -Be 1
            $base.TestSettings[0].Severity | Should -Be 'High'
        }
    }
}

Describe 'Resolve-MtRunConfig' {
    BeforeEach {
        $script:savedEnv = $env:MAESTER_CONFIG
        $env:MAESTER_CONFIG = $null
    }
    AfterEach {
        $env:MAESTER_CONFIG = $script:savedEnv
    }

    It 'Uses a -Config object over the shipped defaults and does not read files under -Path' {
        $folder = Join-Path $TestDrive 'hermetic'
        $null = New-Item -ItemType Directory -Path $folder -Force
        '{ "GlobalSettings": { "FromFile": true }, "TestSettings": [] }' | Set-Content (Join-Path $folder 'maester-config.json')
        $config = InModuleScope Maester -Parameters @{ Folder = $folder } {
            Resolve-MtRunConfig -Path $Folder -Config @{ TestSettings = @(@{ Id = 'MT.1005'; Severity = 'Low' }) }
        }
        $config.GlobalSettings.PSObject.Properties['FromFile'] | Should -BeNullOrEmpty
        $config.TestSettingsHash['MT.1005'].Severity | Should -Be 'Low'
        # A shipped default severity is still present for a test the config does not mention (while the
        # shipped file has rows; they are removed as suites migrate to the native format).
        $shippedRow = InModuleScope Maester { @((Get-MtShippedMaesterConfig).TestSettings) | Where-Object { $_.Id -ne 'MT.1005' } | Select-Object -First 1 }
        if ($shippedRow) { $config.TestSettingsHash[$shippedRow.Id].Severity | Should -Be $shippedRow.Severity }
        $config.ConfigSource | Should -Be '-Config'
    }

    It 'Merges an array of sources left to right' {
        $file = Join-Path $TestDrive 'first.json'
        '{ "TestSettings": [ { "Id": "MT.1005", "Severity": "Low" } ], "Metadata": { "RunId": "1" } }' | Set-Content $file
        $config = InModuleScope Maester -Parameters @{ File = $file } {
            Resolve-MtRunConfig -Config @($File, @{ Metadata = @{ RunId = '2' } })
        }
        $config.TestSettingsHash['MT.1005'].Severity | Should -Be 'Low'
        $config.Metadata.RunId | Should -Be '2'
        $config.ConfigSource | Should -Be 'first.json, -Config'
    }

    It 'Reads MAESTER_CONFIG when -Config is not given' {
        $file = Join-Path $TestDrive 'env.json'
        '{ "Selection": { "TestId": [ "MT.1001" ] } }' | Set-Content $file
        $env:MAESTER_CONFIG = $file
        $config = InModuleScope Maester { Resolve-MtRunConfig -Path $TestDrive }
        $config.Selection.TestId | Should -Be @('MT.1001')
        $config.ConfigSource | Should -BeLike 'MAESTER_CONFIG*'
    }

    It 'Treats an empty file as an empty config' {
        $file = Join-Path $TestDrive 'empty.json'
        '' | Set-Content $file
        $config = InModuleScope Maester -Parameters @{ File = $file } { Resolve-MtRunConfig -Config $File }
        $config.Selection.DefaultAction | Should -Be 'Run'
    }

    It 'Fills every 3.0 section with its defaults' {
        $config = InModuleScope Maester { Resolve-MtRunConfig -Config @{} }
        $config.Selection.BuiltIn | Should -Be 'All'
        $config.Selection.DefaultAction | Should -Be 'Run'
        $config.Selection.OnUnknownId | Should -Be 'Warn'
        $config.Selection.TestId.Count | Should -Be 0
        $config.PSObject.Properties['Metadata'] | Should -Not -BeNullOrEmpty
        $config.PSObject.Properties['GlobalSettings'] | Should -Not -BeNullOrEmpty
    }

    It 'Rejects an unknown DefaultAction' {
        { InModuleScope Maester { Resolve-MtRunConfig -Config @{ Selection = @{ DefaultAction = 'Maybe' } } } } |
            Should -Throw '*DefaultAction*'
    }

    It 'Rejects a missing config file' {
        { InModuleScope Maester { Resolve-MtRunConfig -Config './does-not-exist.json' } } | Should -Throw '*does not exist*'
    }

    It 'Merges the root file and the Custom overlay when no explicit source is given' {
        $folder = Join-Path $TestDrive 'discovered'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Custom') -Force
        '{ "GlobalSettings": {}, "TestSettings": [ { "Id": "MT.1001", "Severity": "Low" } ] }' | Set-Content (Join-Path $folder 'maester-config.json')
        '{ "TestSettings": [ { "Id": "MT.1001", "Severity": "Critical" } ] }' | Set-Content (Join-Path $folder 'Custom/maester-config.json')
        $config = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtRunConfig -Path $Folder }
        $config.TestSettingsHash['MT.1001'].Severity | Should -Be 'Critical'
        $config.ConfigSource | Should -Be 'maester-config.json, Custom/maester-config.json'
    }

    It 'Applies a Custom row to any test ID, not only IDs the root file lists' {
        $folder = Join-Path $TestDrive 'anyid'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Custom') -Force
        '{ "TestSettings": [] }' | Set-Content (Join-Path $folder 'maester-config.json')
        '{ "TestSettings": [ { "Id": "CONTOSO.1", "Severity": "Low", "Enabled": false } ] }' | Set-Content (Join-Path $folder 'Custom/maester-config.json')
        $config = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtRunConfig -Path $Folder }
        $config.TestSettingsHash['CONTOSO.1'].Enabled | Should -BeFalse
    }

    It 'Honours a Custom config with no root file beside it' {
        $folder = Join-Path $TestDrive 'customonly'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Custom') -Force
        '{ "GlobalSettings": { "FromCustom": 1 } }' | Set-Content (Join-Path $folder 'Custom/maester-config.json')
        $config = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtRunConfig -Path $Folder }
        $config.GlobalSettings.FromCustom | Should -Be 1
        $config.ConfigSource | Should -Be 'Custom/maester-config.json'
    }

    It 'Merges the tenant file over the base files instead of replacing them, and warns about inherited settings' {
        $folder = Join-Path $TestDrive 'tenant'
        $tenantId = '11111111-2222-3333-4444-555555555555'
        $null = New-Item -ItemType Directory -Path (Join-Path $folder 'Custom') -Force
        '{ "GlobalSettings": { "EmergencyAccessAccounts": [ "a" ], "Other": "base" }, "TestSettings": [ { "Id": "MT.1001", "Severity": "Low" } ] }' | Set-Content (Join-Path $folder 'maester-config.json')
        '{ "TestSettings": [ { "Id": "MT.1001", "Severity": "High" }, { "Id": "MT.1002", "Severity": "Low" } ] }' | Set-Content (Join-Path $folder 'Custom/maester-config.json')
        '{ "GlobalSettings": { "Other": "tenant" }, "TestSettings": [ { "Id": "MT.1002", "Severity": "Critical" } ] }' | Set-Content (Join-Path $folder "maester-config.$tenantId.json")
        $out = InModuleScope Maester -Parameters @{ Folder = $folder; TenantId = $tenantId } {
            $c = Resolve-MtRunConfig -Path $Folder -TenantId $TenantId -WarningVariable w -WarningAction SilentlyContinue
            [pscustomobject]@{ Config = $c; Warnings = @($w) }
        }
        $config = $out.Config
        $config.GlobalSettings.Other | Should -Be 'tenant'
        $config.GlobalSettings.EmergencyAccessAccounts | Should -Be @('a')
        $config.TestSettingsHash['MT.1001'].Severity | Should -Be 'High'
        $config.TestSettingsHash['MT.1002'].Severity | Should -Be 'Critical'
        $config.ConfigSource | Should -Be "maester-config.json, Custom/maester-config.json, maester-config.$tenantId.json"
        "$($out.Warnings)" | Should -BeLike '*EmergencyAccessAccounts*'
    }

    It 'Uses the shipped defaults when no file is found' {
        $folder = Join-Path $TestDrive 'nothing'
        $null = New-Item -ItemType Directory -Path $folder -Force
        $config = InModuleScope Maester -Parameters @{ Folder = $folder } { Resolve-MtRunConfig -Path $Folder }
        $config.ConfigSource | Should -Be 'defaults'
        $shippedCount = InModuleScope Maester { @((Get-MtShippedMaesterConfig).TestSettings).Count }
        @($config.TestSettings).Count | Should -Be $shippedCount
    }
}

Describe 'Resolve-MtSelection' {
    It 'Lets -Tag and -TestId replace the config lists and -ExcludeTag and -ExcludeTestId add to them' {
        InModuleScope Maester {
            $config = Resolve-MtRunConfig -Config @{ Selection = @{ Tag = @('A'); ExcludeTag = @('B'); TestId = @('X.1'); ExcludeTestId = @('Y.1'); IncludePreview = $true } }
            $s = Resolve-MtSelection -RunConfig $config -Tag 'C' -ExcludeTag 'D' -TestId 'X.2' -ExcludeTestId 'Y.2'
            $s.Tag | Should -Be @('C')
            $s.ExcludeTag | Should -Be @('B', 'D')
            $s.TestId | Should -Be @('X.2')
            $s.ExcludeTestId | Should -Be @('Y.1', 'Y.2')
            $s.IncludePreview | Should -BeTrue
            $s.IncludeLongRunning | Should -BeFalse
        }
    }

    It 'Uses the config lists when no parameter is given' {
        InModuleScope Maester {
            $config = Resolve-MtRunConfig -Config @{ Selection = @{ Tag = @('A'); TestId = @('X.1') } }
            $s = Resolve-MtSelection -RunConfig $config
            $s.Tag | Should -Be @('A')
            $s.TestId | Should -Be @('X.1')
        }
    }
}
