# The mechanical half of the parameter naming rules ("Parameter names" in website/docs/writing-tests/attribute-rubric.md): every
# parameter of a built-in test or a pack that ships with Maester follows one convention, so an admin who
# sets a value in TestSettings can guess its name. Whether a name says what it measures is a judgement; the
# attribute-review workflow and the reviewer check that. Custom tests are not checked here.
#
# It also checks how settings are read: a built-in test receives a setting as a bound parameter and never
# calls Get-MtSetting, a helper never reads a setting that tests bind, and every setting the module or a
# shipped pack reads is declared.

BeforeAll {
    Import-Module "$PSScriptRoot/../../Maester.psd1" -Force -WarningAction SilentlyContinue
    $script:repoRoot = (Resolve-Path "$PSScriptRoot/../../..").Path

    $files = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'tests'), (Join-Path $script:repoRoot 'packs') -Recurse -File -Filter 'Test.*.ps1' |
            Where-Object { $_.FullName -notmatch '[\\/]custom[\\/]' })
    $script:files = $files
    $tests = @(InModuleScope Maester -Parameters @{ Files = $files.FullName } {
            foreach ($file in $Files) { [pscustomobject](Read-MtNativeTest -Path $file -BuiltIn) }
        })
    $script:parameters = @(foreach ($t in $tests) {
            foreach ($p in @($t.Parameters | Where-Object { -not $_.EngineOwned })) {
                [pscustomobject]@{ Id = $t.Id; Name = $p.Name; Type = $p.Type; Setting = $p.Setting; Default = $p.Default; AllowedValues = $p.AllowedValues }
            }
        })
    $script:settings = InModuleScope Maester { (Get-MtSettingRegistry).Settings }

    $script:moduleFiles = @(Get-ChildItem -Path (Join-Path $script:repoRoot 'powershell/internal'), (Join-Path $script:repoRoot 'powershell/public') -Recurse -File -Filter '*.ps1')

    # The Get-MtSetting calls of a file that name the setting with a constant: Name and Line.
    $script:findSettingCall = {
        param([string] $Path)
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$null, [ref]$null)
        $calls = $ast.FindAll({ param($node) $node -is [System.Management.Automation.Language.CommandAst] -and $node.GetCommandName() -in 'Get-MtSetting', 'Get-MtMaesterConfigGlobalSetting' }, $true)
        foreach ($call in $calls) {
            $elements = @($call.CommandElements | Select-Object -Skip 1)
            $name = $null
            for ($i = 0; $i -lt $elements.Count; $i++) {
                $element = $elements[$i]
                if ($element -is [System.Management.Automation.Language.CommandParameterAst]) {
                    if ($element.ParameterName -in 'Name', 'SettingName' -and $i + 1 -lt $elements.Count -and $elements[$i + 1] -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $name = $elements[$i + 1].Value; break }
                    if ($element.ParameterName -in 'Name', 'SettingName', 'Default') { $i++ }
                    continue
                }
                if ($element -is [System.Management.Automation.Language.StringConstantExpressionAst]) { $name = $element.Value; break }
            }
            if ($name) { [pscustomobject]@{ Name = $name; Line = $call.Extent.StartLineNumber } }
        }
    }

    # Reports offenders as "ID: Name - detail" so a failure names every parameter to rename.
    function Get-Offender {
        param([scriptblock] $Where, [scriptblock] $Detail)
        @($script:parameters | Where-Object $Where | ForEach-Object { "$($_.Id): $($_.Name) - $(& $Detail $_)" } | Sort-Object -Unique)
    }
}

Describe 'Names of test parameters' {
    It 'Finds the parameters of the built-in tests' {
        $script:parameters.Count | Should -BeGreaterThan 100
    }

    It 'Uses PascalCase' {
        $offenders = Get-Offender { $_.Name -cnotmatch '^[A-Z][A-Za-z0-9]*$' } { 'start with a capital letter and use letters and digits only' }
        $offenders | Should -BeNullOrEmpty -Because 'parameter names are PascalCase, like PowerShell parameters'
    }

    It 'Spells out Maximum and Minimum' {
        $offenders = Get-Offender { $_.Name -cmatch '^(Max|Min)(?!imum)' } {
            param($p) "rename to $($p.Name -creplace '^Max(?!imum)', 'Maximum' -creplace '^Min(?!imum)', 'Minimum')"
        }
        $offenders | Should -BeNullOrEmpty -Because 'a limit is named Maximum<What><Unit> or Minimum<What><Unit>, never Max or Min'
    }

    It 'Ends a unit with a plain suffix' {
        $offenders = Get-Offender { $_.Name -cmatch 'In(Days|Hours|Minutes|Seconds)$' } {
            param($p) "rename to $($p.Name -creplace 'In(Days|Hours|Minutes|Seconds)$', '$1')"
        }
        $offenders | Should -BeNullOrEmpty -Because 'a unit is a plain suffix: MaximumLifetimeDays, not MaximumLifetimeInDays'
    }

    It 'Names a list in the plural' {
        $offenders = Get-Offender { $_.Type -in 'string[]', 'object[]' -and $_.Name -cnotmatch 's$' } { 'a list takes a plural name, for example ParkedDomains' }
        $offenders | Should -BeNullOrEmpty -Because 'a string[] or object[] parameter holds several values, so its name is plural'
    }

    It 'Avoids the names of PowerShell common parameters' {
        $reserved = 'Force', 'Confirm', 'WhatIf', 'PassThru'
        $offenders = Get-Offender { $_.Name -in $reserved } { 'name what turning it on does, for example AllDomains' }
        $offenders | Should -BeNullOrEmpty -Because 'these names mean something else in PowerShell'
    }

    It 'Gives one name one type' {
        $offenders = @($script:parameters | Group-Object Name | Where-Object { @($_.Group.Type | Sort-Object -Unique).Count -gt 1 } | ForEach-Object {
                "$($_.Name): $(($_.Group | ForEach-Object { "$($_.Id) ($($_.Type))" }) -join ', ')"
            })
        $offenders | Should -BeNullOrEmpty -Because 'a name that holds a number on one test and a list on another means two different things; rename one'
    }

    It 'Binds one name to one setting' {
        # A test may give a bound name a value of its own, but two tests that share a name and bind it must bind the same setting.
        $offenders = @($script:parameters | Where-Object Setting | Group-Object Name | Where-Object { @($_.Group.Setting | Sort-Object -Unique).Count -gt 1 } | ForEach-Object {
                "$($_.Name): $(($_.Group | ForEach-Object { "$($_.Id) ($($_.Setting))" }) -join ', ')"
            })
        $offenders | Should -BeNullOrEmpty -Because 'one parameter name has one meaning wherever it is bound'
    }
}

Describe 'Settings that tests receive as parameters' {
    It 'Binds only registered settings or a pack''s own Namespace.Key settings' {
        $offenders = Get-Offender { $_.Setting -and -not $script:settings.ContainsKey($_.Setting) -and $_.Setting -notmatch '\.' } { "'$($_.Setting)' is not in assets/MaesterSettings.psd1" }
        $offenders | Should -BeNullOrEmpty
    }

    It 'Gives a bound parameter the default and the allowed values of its setting' {
        # The registry is where the config is checked, so a test must not accept or default to anything else.
        $text = { param($v) @($v | Where-Object { $null -ne $_ } | ForEach-Object { "$_" } | Sort-Object) -join ', ' }
        $offenders = foreach ($p in @($script:parameters | Where-Object { $_.Setting -and $script:settings.ContainsKey($_.Setting) })) {
            $entry = $script:settings[$p.Setting]
            if ((& $text $p.Default) -cne (& $text $entry.Default)) { "$($p.Id): $($p.Name) defaults to '$(& $text $p.Default)', setting $($p.Setting) to '$(& $text $entry.Default)'" }
            if ((& $text $p.AllowedValues) -cne (& $text $entry.AllowedValues)) { "$($p.Id): $($p.Name) allows '$(& $text $p.AllowedValues)', setting $($p.Setting) '$(& $text $entry.AllowedValues)'" }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Never reads a setting inside a built-in test' {
        # A test that calls Get-MtSetting hides the value from Get-MtTest, and a TestSettings row cannot
        # override it. A test declares [MaesterParameter(Setting = '...')] and passes the value to its helpers.
        $offenders = foreach ($file in @($script:files | Where-Object { $_.FullName.StartsWith((Join-Path $script:repoRoot 'tests')) })) {
            foreach ($call in @(& $script:findSettingCall $file.FullName)) { "$($file.Name): reads '$($call.Name)' with Get-MtSetting; declare [MaesterParameter(Setting = '$($call.Name)')] instead" }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Never reads a setting that tests bind inside a helper' {
        # A helper that reads the setting itself ignores the value the test was given, so a TestSettings row
        # or -Parameter would change what the result records but not what the helper does.
        $bound = @($script:parameters | Where-Object Setting | ForEach-Object Setting | Sort-Object -Unique)
        $offenders = foreach ($file in $script:moduleFiles) {
            foreach ($call in @(& $script:findSettingCall $file.FullName)) {
                if ($call.Name -in $bound) { "$($file.Name): reads '$($call.Name)' with Get-MtSetting; take it as a parameter from the test instead" }
            }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Reads only registered settings in the module' {
        # An unregistered setting has no type, no default and no documentation, and the config check
        # reports it to the user as a likely typo.
        $offenders = foreach ($file in $script:moduleFiles) {
            foreach ($call in @(& $script:findSettingCall $file.FullName)) {
                if (-not $script:settings.ContainsKey($call.Name)) { "$($file.Name): '$($call.Name)' is not in assets/MaesterSettings.psd1" }
            }
        }
        @($offenders) | Should -BeNullOrEmpty
    }

    It 'Declares the settings a pack reads in its maester-pack.json' {
        $offenders = foreach ($pack in @(Get-ChildItem -Path (Join-Path $script:repoRoot 'packs') -Directory)) {
            $manifestPath = Join-Path $pack.FullName 'maester-pack.json'
            if (-not (Test-Path $manifestPath)) { continue }
            $manifest = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
            $declared = if ($manifest.PSObject.Properties['Settings']) { @($manifest.Settings.PSObject.Properties.Name) } else { @() }
            foreach ($file in @(Get-ChildItem -Path $pack.FullName -Recurse -File -Filter '*.ps1')) {
                foreach ($call in @(& $script:findSettingCall $file.FullName)) {
                    if ($call.Name -notin $declared -and -not $script:settings.ContainsKey($call.Name)) { "$($pack.Name)/$($file.Name): '$($call.Name)' is not under Settings in maester-pack.json" }
                }
            }
        }
        @($offenders) | Should -BeNullOrEmpty
    }
}
